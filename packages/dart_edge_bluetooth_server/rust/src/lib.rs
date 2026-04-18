use std::collections::{HashMap, VecDeque};
use std::ffi::{CStr, CString, c_char};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};

use once_cell::sync::Lazy;
use serde::Deserialize;
use serde_json::{Value, json};

const DART_EDGE_BLUETOOTH_SERVER_NATIVE_ABI_VERSION: i32 = 1;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static SERVERS: Lazy<Mutex<HashMap<i64, NativeBluetoothServer>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

#[derive(Clone, Default)]
struct EventQueue {
    events: Arc<Mutex<VecDeque<String>>>,
}

impl EventQueue {
    fn push_value(&self, value: Value) {
        let Ok(serialized) = serde_json::to_string(&value) else {
            return;
        };
        let mut events = self.events.lock().unwrap_or_else(|poison| poison.into_inner());
        events.push_back(serialized);
    }

    fn poll(&self) -> Option<String> {
        let mut events = self.events.lock().unwrap_or_else(|poison| poison.into_inner());
        events.pop_front()
    }
}

#[derive(Clone)]
struct NativeCharacteristicPath {
    service_id: String,
    characteristic_id: String,
}

impl NativeCharacteristicPath {
    fn to_json(&self) -> Value {
        json!({
            "serviceId": self.service_id,
            "characteristicId": self.characteristic_id,
        })
    }
}

#[derive(Clone)]
struct NativeDescriptorPath {
    service_id: String,
    characteristic_id: String,
    descriptor_id: String,
}

impl NativeDescriptorPath {
    fn to_json(&self) -> Value {
        json!({
            "serviceId": self.service_id,
            "characteristicId": self.characteristic_id,
            "descriptorId": self.descriptor_id,
        })
    }
}

#[derive(Clone)]
struct DescriptorState {
    path: NativeDescriptorPath,
    value: Arc<RwLock<Vec<u8>>>,
    emit_read_events: bool,
    emit_write_events: bool,
    persist_written_value: bool,
    events: EventQueue,
}

impl DescriptorState {
    fn current_value(&self) -> Vec<u8> {
        self.value
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .clone()
    }

    fn replace_value(&self, value: Vec<u8>) {
        *self
            .value
            .write()
            .unwrap_or_else(|poison| poison.into_inner()) = value;
    }

    fn emit_read_event(
        &self,
        device_address: &str,
        offset: u16,
        link_type: Option<&str>,
        value: &[u8],
    ) {
        if !self.emit_read_events {
            return;
        }

        let mut payload = json!({
            "kind": "descriptorRead",
            "timestampMicros": timestamp_micros(),
            "path": self.path.to_json(),
            "value": value,
            "deviceAddress": device_address,
            "offset": offset,
        });
        if let Some(link_type) = link_type {
            payload["linkType"] = json!(link_type);
        }
        self.events.push_value(payload);
    }

    fn emit_write_event(
        &self,
        device_address: &str,
        offset: u16,
        link_type: Option<&str>,
        prepare_authorize: bool,
        value: &[u8],
    ) {
        if !self.emit_write_events {
            return;
        }

        let mut payload = json!({
            "kind": "descriptorWrite",
            "timestampMicros": timestamp_micros(),
            "path": self.path.to_json(),
            "value": value,
            "deviceAddress": device_address,
            "offset": offset,
            "prepareAuthorize": prepare_authorize,
        });
        if let Some(link_type) = link_type {
            payload["linkType"] = json!(link_type);
        }
        self.events.push_value(payload);
    }
}

#[cfg(target_os = "linux")]
type NotifySender = tokio::sync::broadcast::Sender<Vec<u8>>;

#[derive(Clone)]
struct CharacteristicState {
    path: NativeCharacteristicPath,
    value: Arc<RwLock<Vec<u8>>>,
    emit_read_events: bool,
    emit_write_events: bool,
    emit_subscription_events: bool,
    persist_written_value: bool,
    notify_subscribers_on_write: bool,
    events: EventQueue,
    #[cfg(target_os = "linux")]
    notify_tx: NotifySender,
    descriptors: HashMap<String, Arc<DescriptorState>>,
}

impl CharacteristicState {
    fn current_value(&self) -> Vec<u8> {
        self.value
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .clone()
    }

    fn replace_value(&self, value: Vec<u8>) {
        *self
            .value
            .write()
            .unwrap_or_else(|poison| poison.into_inner()) = value;
    }

    #[cfg(target_os = "linux")]
    fn notify_subscribers(&self, value: Vec<u8>) {
        let _ = self.notify_tx.send(value);
    }

    fn emit_read_event(
        &self,
        device_address: &str,
        offset: u16,
        mtu: u16,
        link_type: Option<&str>,
        value: &[u8],
    ) {
        if !self.emit_read_events {
            return;
        }

        let mut payload = json!({
            "kind": "characteristicRead",
            "timestampMicros": timestamp_micros(),
            "path": self.path.to_json(),
            "value": value,
            "deviceAddress": device_address,
            "offset": offset,
            "mtu": mtu,
        });
        if let Some(link_type) = link_type {
            payload["linkType"] = json!(link_type);
        }
        self.events.push_value(payload);
    }

    fn emit_write_event(
        &self,
        device_address: &str,
        offset: u16,
        mtu: u16,
        link_type: Option<&str>,
        operation: Option<&str>,
        prepare_authorize: bool,
        value: &[u8],
    ) {
        if !self.emit_write_events {
            return;
        }

        let mut payload = json!({
            "kind": "characteristicWrite",
            "timestampMicros": timestamp_micros(),
            "path": self.path.to_json(),
            "value": value,
            "deviceAddress": device_address,
            "offset": offset,
            "mtu": mtu,
            "prepareAuthorize": prepare_authorize,
        });
        if let Some(link_type) = link_type {
            payload["linkType"] = json!(link_type);
        }
        if let Some(operation) = operation {
            payload["operation"] = json!(operation);
        }
        self.events.push_value(payload);
    }

    fn emit_subscription_event(&self, subscribed: bool, confirming: bool) {
        if !self.emit_subscription_events {
            return;
        }

        self.events.push_value(json!({
            "kind": "characteristicSubscription",
            "timestampMicros": timestamp_micros(),
            "path": self.path.to_json(),
            "subscribed": subscribed,
            "confirming": confirming,
        }));
    }
}

#[derive(Clone)]
struct ServiceState {
    characteristics: HashMap<String, Arc<CharacteristicState>>,
}

struct SharedBluetoothState {
    services: HashMap<String, Arc<ServiceState>>,
    characteristics: HashMap<(String, String), Arc<CharacteristicState>>,
    descriptors: HashMap<(String, String, String), Arc<DescriptorState>>,
    events: EventQueue,
}

impl SharedBluetoothState {
    fn build(config: &NativeBluetoothServerConfig) -> Result<Arc<Self>, String> {
        let events = EventQueue::default();
        let mut services = HashMap::new();
        let mut characteristics = HashMap::new();
        let mut descriptors = HashMap::new();

        for service in &config.application.services {
            validate_id(&service.id, "service id")?;
            parse_bluetooth_uuid(&service.uuid)?;

            if services.contains_key(&service.id) {
                return Err(format!("Duplicate GATT service id '{}'.", service.id));
            }

            let mut service_characteristics = HashMap::new();

            for characteristic in &service.characteristics {
                validate_id(
                    &characteristic.id,
                    &format!("characteristic id in service '{}'", service.id),
                )?;
                parse_bluetooth_uuid(&characteristic.uuid)?;

                if service_characteristics.contains_key(&characteristic.id) {
                    return Err(format!(
                        "Duplicate characteristic id '{}' in service '{}'.",
                        characteristic.id, service.id
                    ));
                }

                let characteristic_path = NativeCharacteristicPath {
                    service_id: service.id.clone(),
                    characteristic_id: characteristic.id.clone(),
                };

                #[cfg(target_os = "linux")]
                let (notify_tx, _) = tokio::sync::broadcast::channel(32);

                let mut characteristic_descriptors = HashMap::new();
                for descriptor in &characteristic.descriptors {
                    validate_id(
                        &descriptor.id,
                        &format!(
                            "descriptor id in characteristic '{}.{}'",
                            service.id, characteristic.id
                        ),
                    )?;
                    parse_bluetooth_uuid(&descriptor.uuid)?;

                    if characteristic_descriptors.contains_key(&descriptor.id) {
                        return Err(format!(
                            "Duplicate descriptor id '{}' in characteristic '{}.{}'.",
                            descriptor.id, service.id, characteristic.id
                        ));
                    }

                    let descriptor_state = Arc::new(DescriptorState {
                        path: NativeDescriptorPath {
                            service_id: service.id.clone(),
                            characteristic_id: characteristic.id.clone(),
                            descriptor_id: descriptor.id.clone(),
                        },
                        value: Arc::new(RwLock::new(descriptor.initial_value.clone())),
                        emit_read_events: descriptor.read.enabled && descriptor.read.emit_read_events,
                        emit_write_events: descriptor.write.enabled() && descriptor.write.emit_write_events,
                        persist_written_value: descriptor.write.persist_written_value,
                        events: events.clone(),
                    });

                    descriptors.insert(
                        (
                            service.id.clone(),
                            characteristic.id.clone(),
                            descriptor.id.clone(),
                        ),
                        descriptor_state.clone(),
                    );
                    characteristic_descriptors
                        .insert(descriptor.id.clone(), descriptor_state);
                }

                let characteristic_state = Arc::new(CharacteristicState {
                    path: characteristic_path,
                    value: Arc::new(RwLock::new(characteristic.initial_value.clone())),
                    emit_read_events: characteristic.read.enabled
                        && characteristic.read.emit_read_events,
                    emit_write_events: characteristic.write.enabled()
                        && characteristic.write.emit_write_events,
                    emit_subscription_events: characteristic.notify.enabled
                        && characteristic.notify.emit_subscription_events,
                    persist_written_value: characteristic.write.persist_written_value,
                    notify_subscribers_on_write: characteristic.write.notify_subscribers_on_write,
                    events: events.clone(),
                    #[cfg(target_os = "linux")]
                    notify_tx,
                    descriptors: characteristic_descriptors,
                });

                characteristics.insert(
                    (service.id.clone(), characteristic.id.clone()),
                    characteristic_state.clone(),
                );
                service_characteristics.insert(characteristic.id.clone(), characteristic_state);
            }

            services.insert(
                service.id.clone(),
                Arc::new(ServiceState {
                    characteristics: service_characteristics,
                }),
            );
        }

        Ok(Arc::new(Self {
            services,
            characteristics,
            descriptors,
            events,
        }))
    }

    fn poll_event(&self) -> Option<String> {
        self.events.poll()
    }

    fn characteristic(
        &self,
        path: &NativeCharacteristicPathRequest,
    ) -> Result<Arc<CharacteristicState>, String> {
        self.characteristics
            .get(&(path.service_id.clone(), path.characteristic_id.clone()))
            .cloned()
            .ok_or_else(|| {
                format!(
                    "Unknown characteristic path '{}.{}'.",
                    path.service_id, path.characteristic_id
                )
            })
    }

    fn descriptor(
        &self,
        path: &NativeDescriptorPathRequest,
    ) -> Result<Arc<DescriptorState>, String> {
        self.descriptors
            .get(&(
                path.service_id.clone(),
                path.characteristic_id.clone(),
                path.descriptor_id.clone(),
            ))
            .cloned()
            .ok_or_else(|| {
                format!(
                    "Unknown descriptor path '{}.{}.{}'.",
                    path.service_id, path.characteristic_id, path.descriptor_id
                )
            })
    }
}

struct NativeBluetoothServer {
    shared: Arc<SharedBluetoothState>,
    #[cfg(target_os = "linux")]
    platform: LinuxBluetoothPlatform,
}

impl NativeBluetoothServer {
    fn new(config: NativeBluetoothServerConfig) -> Result<Self, String> {
        let shared = SharedBluetoothState::build(&config)?;
        #[cfg(target_os = "linux")]
        let platform = LinuxBluetoothPlatform::new(config, shared.clone())?;

        Ok(Self {
            shared,
            #[cfg(target_os = "linux")]
            platform,
        })
    }

    fn start(&mut self) -> Result<(), String> {
        #[cfg(target_os = "linux")]
        {
            return self.platform.start();
        }

        #[cfg(not(target_os = "linux"))]
        {
            Err(unsupported_platform_message())
        }
    }

    fn stop(&mut self) -> Result<(), String> {
        #[cfg(target_os = "linux")]
        {
            return self.platform.stop();
        }

        #[cfg(not(target_os = "linux"))]
        {
            Ok(())
        }
    }

    fn issue_command(&mut self, command: NativeCommand) -> Result<Value, String> {
        match command.kind.as_str() {
            "setCharacteristicValue" => {
                let path = decode_path::<NativeCharacteristicPathRequest>(&command.path)?;
                let characteristic = self.shared.characteristic(&path)?;
                let value = command.value.unwrap_or_default();
                characteristic.replace_value(value.clone());
                #[cfg(target_os = "linux")]
                if command.notify.unwrap_or(false) {
                    characteristic.notify_subscribers(value);
                }
                Ok(json!({}))
            }
            "readCharacteristicValue" => {
                let path = decode_path::<NativeCharacteristicPathRequest>(&command.path)?;
                let characteristic = self.shared.characteristic(&path)?;
                Ok(json!({
                    "value": characteristic.current_value(),
                }))
            }
            "setDescriptorValue" => {
                let path = decode_path::<NativeDescriptorPathRequest>(&command.path)?;
                let descriptor = self.shared.descriptor(&path)?;
                descriptor.replace_value(command.value.unwrap_or_default());
                Ok(json!({}))
            }
            "readDescriptorValue" => {
                let path = decode_path::<NativeDescriptorPathRequest>(&command.path)?;
                let descriptor = self.shared.descriptor(&path)?;
                Ok(json!({
                    "value": descriptor.current_value(),
                }))
            }
            kind => Err(format!("Unsupported Bluetooth server command '{}'.", kind)),
        }
    }

    fn poll_event(&self) -> Option<String> {
        self.shared.poll_event()
    }
}

impl Drop for NativeBluetoothServer {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

#[cfg(target_os = "linux")]
struct LinuxBluetoothPlatform {
    config: NativeBluetoothServerConfig,
    shared: Arc<SharedBluetoothState>,
    runtime: tokio::runtime::Runtime,
    running: Option<LinuxRunningServer>,
}

#[cfg(target_os = "linux")]
struct LinuxRunningServer {
    _session: bluer::Session,
    _app_handle: bluer::gatt::local::ApplicationHandle,
    _adv_handle: bluer::adv::AdvertisementHandle,
}

#[cfg(target_os = "linux")]
impl LinuxBluetoothPlatform {
    fn new(
        config: NativeBluetoothServerConfig,
        shared: Arc<SharedBluetoothState>,
    ) -> Result<Self, String> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)
            .build()
            .map_err(|error| format!("Failed to build Bluetooth runtime: {error}"))?;

        Ok(Self {
            config,
            shared,
            runtime,
            running: None,
        })
    }

    fn start(&mut self) -> Result<(), String> {
        if self.running.is_some() {
            return Ok(());
        }

        let config = self.config.clone();
        let shared = self.shared.clone();
        let running = self
            .runtime
            .block_on(async move { start_linux_server(config, shared).await })?;
        self.running = Some(running);
        Ok(())
    }

    fn stop(&mut self) -> Result<(), String> {
        if let Some(running) = self.running.take() {
            self.runtime.block_on(async move {
                drop(running);
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            });
        }
        Ok(())
    }
}

#[cfg(target_os = "linux")]
async fn start_linux_server(
    config: NativeBluetoothServerConfig,
    shared: Arc<SharedBluetoothState>,
) -> Result<LinuxRunningServer, String> {
    use bluer::Session;

    let session = Session::new()
        .await
        .map_err(|error| format!("Failed to open BlueZ session: {error}"))?;

    let adapter = if let Some(adapter_name) = config.adapter_name.as_deref() {
        session
            .adapter(adapter_name)
            .map_err(|error| format!("Failed to access Bluetooth adapter '{adapter_name}': {error}"))?
    } else {
        session
            .default_adapter()
            .await
            .map_err(|error| format!("Failed to resolve default Bluetooth adapter: {error}"))?
    };

    if config.auto_power_adapter {
        adapter
            .set_powered(true)
            .await
            .map_err(|error| format!("Failed to power Bluetooth adapter '{}': {error}", adapter.name()))?;
    }

    let advertisement = build_linux_advertisement(&config.advertisement)?;
    let adv_handle = adapter
        .advertise(advertisement)
        .await
        .map_err(|error| format!("Failed to register Bluetooth advertisement: {error}"))?;

    let application = build_linux_application(&config.application, shared)?;
    let app_handle = adapter
        .serve_gatt_application(application)
        .await
        .map_err(|error| format!("Failed to publish GATT application: {error}"))?;

    Ok(LinuxRunningServer {
        _session: session,
        _app_handle: app_handle,
        _adv_handle: adv_handle,
    })
}

#[cfg(target_os = "linux")]
fn build_linux_advertisement(
    advertisement: &NativeBluetoothAdvertisementConfig,
) -> Result<bluer::adv::Advertisement, String> {
    use std::collections::{BTreeMap, BTreeSet};

    let service_uuids = advertisement
        .service_uuids
        .iter()
        .map(|uuid| parse_bluetooth_uuid(uuid))
        .collect::<Result<BTreeSet<_>, _>>()?;

    let manufacturer_data = advertisement
        .manufacturer_data
        .iter()
        .map(|entry| (entry.company_identifier, entry.data.clone()))
        .collect::<BTreeMap<_, _>>();

    let service_data = advertisement
        .service_data
        .iter()
        .map(|entry| parse_bluetooth_uuid(&entry.uuid).map(|uuid| (uuid, entry.data.clone())))
        .collect::<Result<BTreeMap<_, _>, _>>()?;

    Ok(bluer::adv::Advertisement {
        service_uuids,
        manufacturer_data,
        service_data,
        discoverable: Some(advertisement.discoverable),
        local_name: advertisement.local_name.clone(),
        ..Default::default()
    })
}

#[cfg(target_os = "linux")]
fn build_linux_application(
    application: &NativeBluetoothApplicationDefinition,
    shared: Arc<SharedBluetoothState>,
) -> Result<bluer::gatt::local::Application, String> {
    let services = application
        .services
        .iter()
        .map(|service| build_linux_service(service, shared.clone()))
        .collect::<Result<Vec<_>, _>>()?;

    Ok(bluer::gatt::local::Application {
        services,
        ..Default::default()
    })
}

#[cfg(target_os = "linux")]
fn build_linux_service(
    service: &NativeBluetoothServiceDefinition,
    shared: Arc<SharedBluetoothState>,
) -> Result<bluer::gatt::local::Service, String> {
    let characteristics = service
        .characteristics
        .iter()
        .map(|characteristic| {
            build_linux_characteristic(service, characteristic, shared.clone())
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(bluer::gatt::local::Service {
        uuid: parse_bluetooth_uuid(&service.uuid)?,
        primary: service.primary,
        characteristics,
        ..Default::default()
    })
}

#[cfg(target_os = "linux")]
fn build_linux_characteristic(
    service: &NativeBluetoothServiceDefinition,
    characteristic: &NativeBluetoothCharacteristicDefinition,
    shared: Arc<SharedBluetoothState>,
) -> Result<bluer::gatt::local::Characteristic, String> {
    use bluer::gatt::local::{
        Characteristic, CharacteristicNotify, CharacteristicNotifyMethod, CharacteristicRead,
        CharacteristicWrite, CharacteristicWriteMethod,
    };
    use futures::FutureExt;

    let state = shared
        .characteristics
        .get(&(service.id.clone(), characteristic.id.clone()))
        .cloned()
        .ok_or_else(|| {
            format!(
                "Missing characteristic state for '{}.{}'.",
                service.id, characteristic.id
            )
        })?;

    let descriptors = characteristic
        .descriptors
        .iter()
        .map(|descriptor| {
            build_linux_descriptor(service, characteristic, descriptor, shared.clone())
        })
        .collect::<Result<Vec<_>, _>>()?;

    let read = characteristic.read.enabled.then(|| {
        let state = state.clone();
        CharacteristicRead {
            read: characteristic.read.enabled,
            encrypt_read: characteristic.read.requires_encryption,
            encrypt_authenticated_read: characteristic.read.requires_authentication,
            secure_read: characteristic.read.requires_secure_connection,
            fun: Box::new(move |request| {
                let state = state.clone();
                async move {
                    let value = state.current_value();
                    state.emit_read_event(
                        &request.device_address.to_string(),
                        request.offset,
                        request.mtu,
                        request.link.map(link_type_name),
                        &value,
                    );
                    Ok(value)
                }
                .boxed()
            }),
            ..Default::default()
        }
    });

    let write = characteristic.write.enabled().then(|| {
        let state = state.clone();
        CharacteristicWrite {
            write: characteristic.write.allow_write_request,
            write_without_response: characteristic.write.allow_write_command,
            reliable_write: characteristic.write.allow_reliable_write,
            authenticated_signed_writes: characteristic.write
                .allow_authenticated_signed_write,
            encrypt_write: characteristic.write.requires_encryption,
            encrypt_authenticated_write: characteristic.write.requires_authentication,
            secure_write: characteristic.write.requires_secure_connection,
            method: CharacteristicWriteMethod::Fun(Box::new(move |value, request| {
                let state = state.clone();
                async move {
                    if state.persist_written_value {
                        state.replace_value(value.clone());
                    }
                    let operation = request.op_type.to_string();
                    state.emit_write_event(
                        &request.device_address.to_string(),
                        request.offset,
                        request.mtu,
                        request.link.map(link_type_name),
                        Some(&operation),
                        request.prepare_authorize,
                        &value,
                    );
                    if state.notify_subscribers_on_write {
                        let current = state.current_value();
                        state.notify_subscribers(current);
                    }
                    Ok(())
                }
                .boxed()
            })),
            ..Default::default()
        }
    });

    let notify = characteristic.notify.enabled.then(|| {
        let state = state.clone();
        CharacteristicNotify {
            notify: !characteristic.notify.indicate,
            indicate: characteristic.notify.indicate,
            method: CharacteristicNotifyMethod::Fun(Box::new(move |mut notifier| {
                let state = state.clone();
                async move {
                    state.emit_subscription_event(true, notifier.confirming());
                    let mut receiver = state.notify_tx.subscribe();

                    loop {
                        let stopped = notifier.stopped();
                        tokio::pin!(stopped);

                        tokio::select! {
                            _ = &mut stopped => break,
                            update = receiver.recv() => match update {
                                Ok(value) => {
                                    if notifier.notify(value).await.is_err() {
                                        break;
                                    }
                                }
                                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                                    let value = state.current_value();
                                    if notifier.notify(value).await.is_err() {
                                        break;
                                    }
                                }
                                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                            }
                        }
                    }

                    state.emit_subscription_event(false, notifier.confirming());
                }
                .boxed()
            })),
            ..Default::default()
        }
    });

    Ok(Characteristic {
        uuid: parse_bluetooth_uuid(&characteristic.uuid)?,
        broadcast: characteristic.broadcast,
        writable_auxiliaries: characteristic.writable_auxiliaries,
        authorize: characteristic.authorize,
        descriptors,
        read,
        write,
        notify,
        ..Default::default()
    })
}

#[cfg(target_os = "linux")]
fn build_linux_descriptor(
    service: &NativeBluetoothServiceDefinition,
    characteristic: &NativeBluetoothCharacteristicDefinition,
    descriptor: &NativeBluetoothDescriptorDefinition,
    shared: Arc<SharedBluetoothState>,
) -> Result<bluer::gatt::local::Descriptor, String> {
    use bluer::gatt::local::{Descriptor, DescriptorRead, DescriptorWrite};
    use futures::FutureExt;

    let state = shared
        .descriptors
        .get(&(
            service.id.clone(),
            characteristic.id.clone(),
            descriptor.id.clone(),
        ))
        .cloned()
        .ok_or_else(|| {
            format!(
                "Missing descriptor state for '{}.{}.{}'.",
                service.id, characteristic.id, descriptor.id
            )
        })?;

    let read = descriptor.read.enabled.then(|| {
        let state = state.clone();
        DescriptorRead {
            read: descriptor.read.enabled,
            encrypt_read: descriptor.read.requires_encryption,
            encrypt_authenticated_read: descriptor.read.requires_authentication,
            secure_read: descriptor.read.requires_secure_connection,
            fun: Box::new(move |request| {
                let state = state.clone();
                async move {
                    let value = state.current_value();
                    state.emit_read_event(
                        &request.device_address.to_string(),
                        request.offset,
                        request.link.map(link_type_name),
                        &value,
                    );
                    Ok(value)
                }
                .boxed()
            }),
            ..Default::default()
        }
    });

    let write = descriptor.write.enabled().then(|| {
        let state = state.clone();
        DescriptorWrite {
            write: descriptor.write.allow_write_request
                || descriptor.write.allow_write_command
                || descriptor.write.allow_reliable_write
                || descriptor.write.allow_authenticated_signed_write,
            encrypt_write: descriptor.write.requires_encryption,
            encrypt_authenticated_write: descriptor.write.requires_authentication,
            secure_write: descriptor.write.requires_secure_connection,
            fun: Box::new(move |value, request| {
                let state = state.clone();
                async move {
                    if state.persist_written_value {
                        state.replace_value(value.clone());
                    }
                    state.emit_write_event(
                        &request.device_address.to_string(),
                        request.offset,
                        request.link.map(link_type_name),
                        request.prepare_authorize,
                        &value,
                    );
                    Ok(())
                }
                .boxed()
            }),
            ..Default::default()
        }
    });

    Ok(Descriptor {
        uuid: parse_bluetooth_uuid(&descriptor.uuid)?,
        authorize: descriptor.authorize,
        read,
        write,
        ..Default::default()
    })
}

#[cfg(target_os = "linux")]
fn link_type_name(link: bluer::gatt::local::LinkType) -> &'static str {
    match link {
        bluer::gatt::local::LinkType::Le => "le",
        bluer::gatt::local::LinkType::BrEdr => "brEdr",
    }
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothServerConfig {
    server_name: String,
    adapter_name: Option<String>,
    #[serde(default = "default_true")]
    auto_power_adapter: bool,
    advertisement: NativeBluetoothAdvertisementConfig,
    application: NativeBluetoothApplicationDefinition,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothAdvertisementConfig {
    local_name: Option<String>,
    #[serde(default = "default_true")]
    discoverable: bool,
    #[serde(default)]
    service_uuids: Vec<String>,
    #[serde(default)]
    manufacturer_data: Vec<NativeBluetoothManufacturerData>,
    #[serde(default)]
    service_data: Vec<NativeBluetoothServiceData>,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothManufacturerData {
    company_identifier: u16,
    #[serde(default)]
    data: Vec<u8>,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothServiceData {
    uuid: String,
    #[serde(default)]
    data: Vec<u8>,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothApplicationDefinition {
    #[serde(default)]
    services: Vec<NativeBluetoothServiceDefinition>,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothServiceDefinition {
    id: String,
    uuid: String,
    #[serde(default = "default_true")]
    primary: bool,
    #[serde(default)]
    characteristics: Vec<NativeBluetoothCharacteristicDefinition>,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothCharacteristicDefinition {
    id: String,
    uuid: String,
    #[serde(default)]
    initial_value: Vec<u8>,
    #[serde(default)]
    broadcast: bool,
    #[serde(default)]
    writable_auxiliaries: bool,
    #[serde(default)]
    authorize: bool,
    #[serde(default)]
    read: NativeBluetoothReadAccess,
    #[serde(default)]
    write: NativeBluetoothWriteAccess,
    #[serde(default)]
    notify: NativeBluetoothNotifyAccess,
    #[serde(default)]
    descriptors: Vec<NativeBluetoothDescriptorDefinition>,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothDescriptorDefinition {
    id: String,
    uuid: String,
    #[serde(default)]
    initial_value: Vec<u8>,
    #[serde(default)]
    authorize: bool,
    #[serde(default)]
    read: NativeBluetoothReadAccess,
    #[serde(default)]
    write: NativeBluetoothWriteAccess,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothReadAccess {
    #[serde(default)]
    enabled: bool,
    #[serde(default)]
    requires_encryption: bool,
    #[serde(default)]
    requires_authentication: bool,
    #[serde(default)]
    requires_secure_connection: bool,
    #[serde(default = "default_true")]
    emit_read_events: bool,
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothWriteAccess {
    #[serde(default)]
    allow_write_request: bool,
    #[serde(default)]
    allow_write_command: bool,
    #[serde(default)]
    allow_reliable_write: bool,
    #[serde(default)]
    allow_authenticated_signed_write: bool,
    #[serde(default)]
    requires_encryption: bool,
    #[serde(default)]
    requires_authentication: bool,
    #[serde(default)]
    requires_secure_connection: bool,
    #[serde(default = "default_true")]
    persist_written_value: bool,
    #[serde(default = "default_true")]
    emit_write_events: bool,
    #[serde(default)]
    notify_subscribers_on_write: bool,
}

impl NativeBluetoothWriteAccess {
    fn enabled(&self) -> bool {
        self.allow_write_request
            || self.allow_write_command
            || self.allow_reliable_write
            || self.allow_authenticated_signed_write
    }
}

#[derive(Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBluetoothNotifyAccess {
    #[serde(default)]
    enabled: bool,
    #[serde(default)]
    indicate: bool,
    #[serde(default = "default_true")]
    emit_subscription_events: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeCommand {
    kind: String,
    path: Option<Value>,
    value: Option<Vec<u8>>,
    notify: Option<bool>,
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeCharacteristicPathRequest {
    service_id: String,
    characteristic_id: String,
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeDescriptorPathRequest {
    service_id: String,
    characteristic_id: String,
    descriptor_id: String,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_native_abi_version() -> i32 {
    DART_EDGE_BLUETOOTH_SERVER_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_is_supported_platform() -> bool {
    cfg!(target_os = "linux")
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_create(config_json: *const c_char) -> i64 {
    let Some(config_json) = (unsafe { read_c_string(config_json) }) else {
        set_last_error("Missing Bluetooth server config.");
        return 0;
    };

    let config = match serde_json::from_str::<NativeBluetoothServerConfig>(&config_json) {
        Ok(config) => config,
        Err(error) => {
            set_last_error(format!("Invalid Bluetooth server config: {error}"));
            return 0;
        }
    };

    let server = match NativeBluetoothServer::new(config) {
        Ok(server) => server,
        Err(error) => {
            set_last_error(error);
            return 0;
        }
    };

    let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
    let mut servers = SERVERS.lock().unwrap_or_else(|poison| poison.into_inner());
    servers.insert(handle, server);
    clear_last_error();
    handle
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_start(handle: i64) -> bool {
    match with_server_mut(handle, |server| server.start()) {
        Ok(()) => {
            clear_last_error();
            true
        }
        Err(error) => {
            set_last_error(error);
            false
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_stop(handle: i64) -> bool {
    match with_server_mut(handle, |server| server.stop()) {
        Ok(()) => {
            clear_last_error();
            true
        }
        Err(error) => {
            set_last_error(error);
            false
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_dispose(handle: i64) {
    let mut servers = SERVERS.lock().unwrap_or_else(|poison| poison.into_inner());
    if let Some(mut server) = servers.remove(&handle) {
        let _ = server.stop();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_issue_command(
    handle: i64,
    command_json: *const c_char,
) -> *mut c_char {
    let Some(command_json) = (unsafe { read_c_string(command_json) }) else {
        set_last_error("Missing Bluetooth server command.");
        return std::ptr::null_mut();
    };

    let command = match serde_json::from_str::<NativeCommand>(&command_json) {
        Ok(command) => command,
        Err(error) => {
            set_last_error(format!("Invalid Bluetooth server command: {error}"));
            return std::ptr::null_mut();
        }
    };

    match with_server_mut(handle, |server| server.issue_command(command)) {
        Ok(payload) => match encode_json_value(payload) {
            Ok(result) => {
                clear_last_error();
                result
            }
            Err(error) => {
                set_last_error(error);
                std::ptr::null_mut()
            }
        },
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_poll_event(handle: i64) -> *mut c_char {
    let servers = SERVERS.lock().unwrap_or_else(|poison| poison.into_inner());
    let Some(server) = servers.get(&handle) else {
        set_last_error(format!("Unknown Bluetooth server handle '{handle}'."));
        return std::ptr::null_mut();
    };

    match server.poll_event() {
        Some(event) => match CString::new(event) {
            Ok(event) => event.into_raw(),
            Err(error) => {
                set_last_error(format!("Failed to encode Bluetooth event: {error}"));
                std::ptr::null_mut()
            }
        },
        None => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_take_last_error() -> *mut c_char {
    let mut last_error = LAST_ERROR.lock().unwrap_or_else(|poison| poison.into_inner());
    match last_error.take() {
        Some(error) => error.into_raw(),
        None => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_bluetooth_server_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

fn with_server_mut<T>(
    handle: i64,
    apply: impl FnOnce(&mut NativeBluetoothServer) -> Result<T, String>,
) -> Result<T, String> {
    let mut servers = SERVERS.lock().unwrap_or_else(|poison| poison.into_inner());
    let server = servers
        .get_mut(&handle)
        .ok_or_else(|| format!("Unknown Bluetooth server handle '{handle}'."))?;
    apply(server)
}

fn decode_path<T>(path: &Option<Value>) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    let path = path
        .clone()
        .ok_or_else(|| "Missing Bluetooth server command path.".to_string())?;
    serde_json::from_value(path).map_err(|error| format!("Invalid Bluetooth command path: {error}"))
}

fn validate_id(value: &str, field_name: &str) -> Result<(), String> {
    if value.trim().is_empty() {
        return Err(format!("Bluetooth {field_name} must not be empty."));
    }
    Ok(())
}

fn parse_bluetooth_uuid(value: &str) -> Result<uuid::Uuid, String> {
    let trimmed = value.trim();
    let parsed = if trimmed.len() == 4 && trimmed.chars().all(|char| char.is_ascii_hexdigit()) {
        uuid::Uuid::parse_str(&format!(
            "0000{}-0000-1000-8000-00805f9b34fb",
            trimmed.to_ascii_lowercase()
        ))
    } else if trimmed.len() == 8 && trimmed.chars().all(|char| char.is_ascii_hexdigit()) {
        uuid::Uuid::parse_str(&format!(
            "{}-0000-1000-8000-00805f9b34fb",
            trimmed.to_ascii_lowercase()
        ))
    } else {
        uuid::Uuid::parse_str(trimmed)
    };

    parsed.map_err(|error| format!("Invalid Bluetooth UUID '{value}': {error}"))
}

fn timestamp_micros() -> u64 {
    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_micros() as u64,
        Err(_) => 0,
    }
}

fn default_true() -> bool {
    true
}

fn unsupported_platform_message() -> String {
    "dart_edge_bluetooth_server currently supports the bluer backend only on Linux with BlueZ."
        .to_string()
}

fn encode_json_value(value: Value) -> Result<*mut c_char, String> {
    let encoded = serde_json::to_string(&value)
        .map_err(|error| format!("Failed to encode JSON value: {error}"))?;
    CString::new(encoded)
        .map(CString::into_raw)
        .map_err(|error| format!("Failed to encode native string: {error}"))
}

unsafe fn read_c_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }
    Some(unsafe { CStr::from_ptr(value) }.to_string_lossy().into_owned())
}

fn set_last_error(error: impl Into<String>) {
    let error = error.into();
    let c_string = CString::new(error).unwrap_or_else(|_| {
        CString::new("dart_edge_bluetooth_server native error").expect("valid static string")
    });
    let mut last_error = LAST_ERROR.lock().unwrap_or_else(|poison| poison.into_inner());
    *last_error = Some(c_string);
}

fn clear_last_error() {
    let mut last_error = LAST_ERROR.lock().unwrap_or_else(|poison| poison.into_inner());
    *last_error = None;
}
