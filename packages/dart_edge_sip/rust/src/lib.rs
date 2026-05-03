use std::collections::{HashMap, HashSet};
use std::ffi::{CStr, CString, c_char};
use std::ptr::NonNull;
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use dart_edge_core::{NativeOwnedBytes, free_owned_bytes, into_native_owned_bytes};
use once_cell::sync::Lazy;
use serde::Deserialize;
use serde_json::{Value, json};

const DART_EDGE_SIP_NATIVE_ABI_VERSION: i32 = 3;
const ERROR_BUFFER_LEN: usize = 1024;
const SESSION_BUFFER_LEN: usize = 128;
const STORAGE_BUFFER_LEN: usize = 1024;

const BRIDGE_EVENT_REGISTRATION: i32 = 2;
const BRIDGE_EVENT_TRUNK: i32 = 3;
const BRIDGE_EVENT_RECORDING: i32 = 4;
const BRIDGE_EVENT_VOICEMAIL: i32 = 5;
const BRIDGE_DIRECTION_INBOUND: i32 = 0;
const BRIDGE_CALL_INVITING: i32 = 0;
const BRIDGE_CALL_RINGING: i32 = 1;
const BRIDGE_CALL_ESTABLISHED: i32 = 2;
const BRIDGE_CALL_BRIDGED: i32 = 3;
const BRIDGE_CALL_ON_HOLD: i32 = 4;
const BRIDGE_CALL_TRANSFERRING: i32 = 5;
const BRIDGE_CALL_REJECTED: i32 = 6;
const BRIDGE_CALL_TERMINATED: i32 = 7;
const BRIDGE_REGISTRATION_REGISTERED: i32 = 0;
const BRIDGE_REGISTRATION_UNREGISTERED: i32 = 1;
const BRIDGE_REGISTRATION_AUTHENTICATION_FAILED: i32 = 2;
const BRIDGE_TRUNK_CONNECTED: i32 = 0;
const BRIDGE_TRUNK_DISCONNECTED: i32 = 1;
const BRIDGE_TRUNK_FAILED: i32 = 2;
const BRIDGE_RECORDING_STARTED: i32 = 0;
const BRIDGE_RECORDING_STOPPED: i32 = 1;
const BRIDGE_RECORDING_COMPLETED: i32 = 2;
const BRIDGE_VOICEMAIL_QUEUED: i32 = 0;
const BRIDGE_VOICEMAIL_STORED: i32 = 1;
const BRIDGE_VOICEMAIL_FAILED: i32 = 2;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static SERVERS: Lazy<Mutex<HashMap<i64, NativeSipServer>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

struct NativeSipServer {
    config: NativeSipServerConfig,
    runtime: Option<PjsipRuntime>,
    started: bool,
}

#[derive(Deserialize)]
struct NativeCommand {
    kind: String,
    #[serde(rename = "sessionId")]
    session_id: Option<String>,
    payload: Option<Value>,
    request: Option<Value>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeOriginateRequest {
    trunk_id: String,
    from_uri: String,
    to_uri: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeEndpointCallRequest {
    endpoint_id: String,
    from_uri: Option<String>,
    to_uri: Option<String>,
}

#[derive(Default, Deserialize)]
struct NativeStatusPayload {
    status: Option<u32>,
    reason: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBridgePayload {
    other_call_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeRouteEndpointPayload {
    endpoint_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeRouteTrunkPayload {
    trunk_id: String,
    target_uri: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeTransferPayload {
    target_uri: String,
    attended_call_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativePromptPayload {
    prompt_id: String,
    media_uri: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeRecordingPayload {
    recording_id: String,
    destination_uri: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeVoicemailPayload {
    mailbox: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeMediaAppPayload {
    media_app_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeTrunkPayload {
    trunk: NativeSipTrunkConfig,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeUpdateTrunkPayload {
    trunk_id: String,
    trunk: NativeSipTrunkConfig,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeTrunkIdPayload {
    trunk_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeTrunkRegistrationPayload {
    trunk_id: String,
    enabled: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipServerConfig {
    server_name: String,
    engine: NativeSipEngineConfig,
    transports: Vec<NativeSipTransportBinding>,
    realms: Vec<NativeSipRealmConfig>,
    endpoints: Vec<NativeSipEndpointConfig>,
    trunks: Vec<NativeSipTrunkConfig>,
    media: NativeSipMediaConfig,
    recordings: NativeSipStorageConfig,
    voicemail: NativeSipVoicemailStorageConfig,
    features: NativeSipFeatureFlags,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipEngineConfig {
    kind: String,
    license_mode: String,
    max_calls: u32,
    max_registrations: u32,
    max_conference_ports: u32,
    worker_threads: u32,
    enable_ice: bool,
    enable_turn: bool,
    enable_tls: bool,
    enable_srtp: bool,
    enable_rport: bool,
    user_agent: String,
}

#[derive(Deserialize)]
struct NativeSipTransportBinding {
    protocol: String,
    host: String,
    port: u16,
    #[serde(rename = "tlsProfile")]
    tls_profile: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipRealmConfig {
    domain: String,
    realm: String,
    require_authentication: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipEndpointConfig {
    id: String,
    extension: String,
    username: String,
    password: String,
    realm: String,
    display_name: Option<String>,
    allow_registrations: bool,
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipTrunkConfig {
    id: String,
    direction: String,
    server_uri: String,
    username: Option<String>,
    password: Option<String>,
    realm: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipMediaConfig {
    rtp_start_port: u16,
    rtp_end_port: u16,
    external_address: Option<String>,
    enable_srtp: bool,
    enable_dtmf_detection: bool,
}

#[derive(Deserialize)]
struct NativeSipStorageConfig {
    enabled: bool,
    directory: Option<String>,
    retention_days: Option<u32>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeSipVoicemailStorageConfig {
    enabled: bool,
    directory: Option<String>,
    default_greeting_uri: Option<String>,
}

#[derive(Deserialize)]
struct NativeSipFeatureFlags {
    registrar: bool,
    authentication: bool,
    bridging: bool,
    transfers: bool,
    ivr: bool,
    recording: bool,
    voicemail: bool,
}

struct PjsipRuntime {
    raw: NonNull<dart_edge_sip_bridge_runtime>,
}

unsafe impl Send for PjsipRuntime {}

impl PjsipRuntime {
    fn from_config(config: &NativeSipServerConfig) -> Result<Self, String> {
        let mut error = ErrorBuffer::new();

        let user_agent = c_string(&config.engine.user_agent)?;
        let external_address = optional_c_string(config.media.external_address.as_deref())?;
        let recording_directory = if config.recordings.enabled {
            optional_c_string(config.recordings.directory.as_deref())?
        } else {
            None
        };
        let voicemail_directory = if config.voicemail.enabled {
            optional_c_string(config.voicemail.directory.as_deref())?
        } else {
            None
        };
        let default_greeting_uri =
            optional_c_string(config.voicemail.default_greeting_uri.as_deref())?;

        let bridge_config = dart_edge_sip_bridge_config {
            max_calls: config.engine.max_calls,
            worker_threads: config.engine.worker_threads,
            max_media_ports: config.engine.max_conference_ports,
            rtp_start_port: u32::from(config.media.rtp_start_port),
            rtp_end_port: u32::from(config.media.rtp_end_port),
            enable_ice: config.engine.enable_ice,
            enable_turn: config.engine.enable_turn,
            enable_tls: config.engine.enable_tls,
            enable_srtp: config.engine.enable_srtp && config.media.enable_srtp,
            enable_rport: config.engine.enable_rport,
            enable_registrar: config.features.registrar,
            user_agent: user_agent.as_ptr(),
            external_address: external_address
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            recording_directory: recording_directory
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            voicemail_directory: voicemail_directory
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            default_greeting_uri: default_greeting_uri
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
        };

        let raw = unsafe {
            dart_edge_sip_bridge_runtime_create(&bridge_config, error.as_mut_ptr(), error.len())
        };
        let raw =
            NonNull::new(raw).ok_or_else(|| error.message("Failed to create PJSIP runtime."))?;
        let mut runtime = Self { raw };

        for transport in &config.transports {
            runtime.add_transport(transport, config.media.external_address.as_deref())?;
        }
        for endpoint in &config.endpoints {
            runtime.add_endpoint(endpoint, config)?;
        }
        for trunk in &config.trunks {
            runtime.add_trunk(trunk)?;
        }

        runtime.start()?;
        Ok(runtime)
    }

    fn add_transport(
        &mut self,
        transport: &NativeSipTransportBinding,
        external_address: Option<&str>,
    ) -> Result<(), String> {
        let host = c_string(&transport.host)?;
        let public_address = optional_c_string(external_address)?;
        let tls_profile = optional_c_string(transport.tls_profile.as_deref())?;
        let mut error = ErrorBuffer::new();
        let binding = dart_edge_sip_bridge_transport_config {
            protocol: match transport.protocol.as_str() {
                "udp" => 0,
                "tcp" => 1,
                "tls" => 2,
                value => return Err(format!("Unsupported SIP transport protocol '{value}'.")),
            },
            host: host.as_ptr(),
            port: u32::from(transport.port),
            public_address: public_address
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            tls_profile: tls_profile
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
        };

        let ok = unsafe {
            dart_edge_sip_bridge_add_transport(
                self.raw.as_ptr(),
                &binding,
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to add SIP transport."))
        }
    }

    fn add_trunk(&mut self, trunk: &NativeSipTrunkConfig) -> Result<(), String> {
        self.with_trunk_binding(
            trunk,
            |runtime, trunk, error, error_len| unsafe {
                dart_edge_sip_bridge_add_trunk(runtime, trunk, error, error_len)
            },
            "Failed to add SIP trunk.",
        )
    }

    fn update_trunk(&mut self, trunk_id: &str, trunk: &NativeSipTrunkConfig) -> Result<(), String> {
        let trunk_id = c_string(trunk_id)?;
        self.with_trunk_binding(
            trunk,
            |runtime, trunk, error, error_len| unsafe {
                dart_edge_sip_bridge_update_trunk(
                    runtime,
                    trunk_id.as_ptr(),
                    trunk,
                    error,
                    error_len,
                )
            },
            "Failed to update SIP trunk.",
        )
    }

    fn remove_trunk(&mut self, trunk_id: &str) -> Result<(), String> {
        let trunk_id = c_string(trunk_id)?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_remove_trunk(
                self.raw.as_ptr(),
                trunk_id.as_ptr(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to remove SIP trunk."))
        }
    }

    fn set_trunk_registration(&mut self, trunk_id: &str, enabled: bool) -> Result<(), String> {
        let trunk_id = c_string(trunk_id)?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_set_trunk_registration(
                self.raw.as_ptr(),
                trunk_id.as_ptr(),
                enabled,
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to change SIP trunk registration."))
        }
    }

    fn with_trunk_binding(
        &mut self,
        trunk: &NativeSipTrunkConfig,
        command: impl FnOnce(
            *mut dart_edge_sip_bridge_runtime,
            *const dart_edge_sip_bridge_trunk_config,
            *mut c_char,
            usize,
        ) -> bool,
        context: &str,
    ) -> Result<(), String> {
        let id = c_string(&trunk.id)?;
        let server_uri = c_string(&trunk.server_uri)?;
        let username = optional_c_string(trunk.username.as_deref())?;
        let password = optional_c_string(trunk.password.as_deref())?;
        let realm = optional_c_string(trunk.realm.as_deref())?;
        let mut error = ErrorBuffer::new();
        let binding = dart_edge_sip_bridge_trunk_config {
            id: id.as_ptr(),
            server_uri: server_uri.as_ptr(),
            username: username
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            password: password
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            realm: realm
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            direction: match trunk.direction.as_str() {
                "inbound" => 0,
                "outbound" => 1,
                "bidirectional" => 2,
                value => return Err(format!("Unsupported SIP trunk direction '{value}'.")),
            },
        };

        let ok = command(self.raw.as_ptr(), &binding, error.as_mut_ptr(), error.len());
        if ok {
            Ok(())
        } else {
            Err(error.message(context))
        }
    }

    fn add_endpoint(
        &mut self,
        endpoint: &NativeSipEndpointConfig,
        config: &NativeSipServerConfig,
    ) -> Result<(), String> {
        let id = c_string(&endpoint.id)?;
        let extension = c_string(&endpoint.extension)?;
        let username = c_string(&endpoint.username)?;
        let password = c_string(&endpoint.password)?;
        let realm = c_string(&endpoint.realm)?;
        let display_name = optional_c_string(endpoint.display_name.as_deref())?;
        let require_authentication = config.features.authentication
            && config
                .realms
                .iter()
                .find(|realm| realm.realm == endpoint.realm || realm.domain == endpoint.realm)
                .is_none_or(|realm| realm.require_authentication);
        let mut error = ErrorBuffer::new();
        let binding = dart_edge_sip_bridge_endpoint_config {
            id: id.as_ptr(),
            extension: extension.as_ptr(),
            username: username.as_ptr(),
            password: password.as_ptr(),
            realm: realm.as_ptr(),
            display_name: display_name
                .as_ref()
                .map_or(std::ptr::null(), |value| value.as_ptr()),
            allow_registrations: config.features.registrar && endpoint.allow_registrations,
            require_authentication,
        };

        let ok = unsafe {
            dart_edge_sip_bridge_add_endpoint(
                self.raw.as_ptr(),
                &binding,
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to add SIP endpoint."))
        }
    }

    fn start(&mut self) -> Result<(), String> {
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_start(self.raw.as_ptr(), error.as_mut_ptr(), error.len())
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to start PJSIP runtime."))
        }
    }

    fn stop(&mut self) -> Result<(), String> {
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_stop(self.raw.as_ptr(), error.as_mut_ptr(), error.len())
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to stop PJSIP runtime."))
        }
    }

    fn originate_call(&mut self, request: &NativeOriginateRequest) -> Result<String, String> {
        let trunk_id = c_string(&request.trunk_id)?;
        let from_uri = c_string(&request.from_uri)?;
        let to_uri = c_string(&request.to_uri)?;
        let mut session_id = [0 as c_char; SESSION_BUFFER_LEN];
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_originate_call(
                self.raw.as_ptr(),
                trunk_id.as_ptr(),
                from_uri.as_ptr(),
                to_uri.as_ptr(),
                session_id.as_mut_ptr(),
                session_id.len(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to originate SIP call."));
        }

        read_fixed_c_string(&session_id)
            .ok_or_else(|| "SIP bridge returned no call session ID.".to_string())
    }

    fn originate_endpoint_call(
        &mut self,
        request: &NativeEndpointCallRequest,
    ) -> Result<String, String> {
        let endpoint_id = c_string(&request.endpoint_id)?;
        let from_uri = optional_c_string(request.from_uri.as_deref())?;
        let to_uri = optional_c_string(request.to_uri.as_deref())?;
        let mut session_id = [0 as c_char; SESSION_BUFFER_LEN];
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_originate_endpoint_call(
                self.raw.as_ptr(),
                endpoint_id.as_ptr(),
                from_uri
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                to_uri
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                session_id.as_mut_ptr(),
                session_id.len(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to originate SIP endpoint call."));
        }

        read_fixed_c_string(&session_id)
            .ok_or_else(|| "SIP bridge returned no call session ID.".to_string())
    }

    fn route_call_to_endpoint(
        &mut self,
        session_id: &str,
        payload: &NativeRouteEndpointPayload,
    ) -> Result<String, String> {
        let session_id = c_string(session_id)?;
        let endpoint_id = c_string(&payload.endpoint_id)?;
        let mut routed_session_id = [0 as c_char; SESSION_BUFFER_LEN];
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_route_call_to_endpoint(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                endpoint_id.as_ptr(),
                routed_session_id.as_mut_ptr(),
                routed_session_id.len(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to route SIP call to endpoint."));
        }

        read_fixed_c_string(&routed_session_id)
            .ok_or_else(|| "SIP bridge returned no routed call session ID.".to_string())
    }

    fn route_call_to_trunk(
        &mut self,
        session_id: &str,
        payload: &NativeRouteTrunkPayload,
    ) -> Result<String, String> {
        let session_id = c_string(session_id)?;
        let trunk_id = c_string(&payload.trunk_id)?;
        let target_uri = optional_c_string(payload.target_uri.as_deref())?;
        let mut routed_session_id = [0 as c_char; SESSION_BUFFER_LEN];
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_route_call_to_trunk(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                trunk_id.as_ptr(),
                target_uri
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                routed_session_id.as_mut_ptr(),
                routed_session_id.len(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to route SIP call to trunk."));
        }

        read_fixed_c_string(&routed_session_id)
            .ok_or_else(|| "SIP bridge returned no routed call session ID.".to_string())
    }

    fn registered_endpoints(&mut self) -> Vec<Value> {
        let count = unsafe {
            dart_edge_sip_bridge_list_registered_endpoints(
                self.raw.as_ptr(),
                std::ptr::null_mut(),
                0,
            )
        };
        if count == 0 {
            return Vec::new();
        }

        let mut endpoints = vec![dart_edge_sip_bridge_registered_endpoint::default(); count];
        let written = unsafe {
            dart_edge_sip_bridge_list_registered_endpoints(
                self.raw.as_ptr(),
                endpoints.as_mut_ptr(),
                endpoints.len(),
            )
        };
        endpoints
            .into_iter()
            .take(written)
            .map(|endpoint| {
                let expires_at_epoch_seconds = endpoint.expires_at_epoch_seconds;
                json!({
                    "endpointId": string_or_empty(&endpoint.endpoint_id),
                    "contactUri": string_or_empty(&endpoint.contact_uri),
                    "expiresAtEpochSeconds": expires_at_epoch_seconds,
                })
            })
            .collect()
    }

    fn answer_call(
        &mut self,
        session_id: &str,
        payload: &NativeStatusPayload,
    ) -> Result<(), String> {
        self.with_status_command(
            session_id,
            payload,
            dart_edge_sip_bridge_answer_call,
            "Failed to answer SIP call.",
        )
    }

    fn reject_call(
        &mut self,
        session_id: &str,
        payload: &NativeStatusPayload,
    ) -> Result<(), String> {
        self.with_status_command(
            session_id,
            payload,
            dart_edge_sip_bridge_reject_call,
            "Failed to reject SIP call.",
        )
    }

    fn hangup_call(
        &mut self,
        session_id: &str,
        payload: &NativeStatusPayload,
    ) -> Result<(), String> {
        self.with_status_command(
            session_id,
            payload,
            dart_edge_sip_bridge_hangup_call,
            "Failed to hang up SIP call.",
        )
    }

    fn bridge_calls(
        &mut self,
        session_id: &str,
        payload: &NativeBridgePayload,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let other_call_id = c_string(&payload.other_call_id)?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_bridge_calls(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                other_call_id.as_ptr(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to bridge SIP calls."))
        }
    }

    fn hold_call(&mut self, session_id: &str) -> Result<(), String> {
        self.with_session_command(
            session_id,
            dart_edge_sip_bridge_hold_call,
            "Failed to place SIP call on hold.",
        )
    }

    fn resume_call(&mut self, session_id: &str) -> Result<(), String> {
        self.with_session_command(
            session_id,
            dart_edge_sip_bridge_resume_call,
            "Failed to resume SIP call.",
        )
    }

    fn transfer_call(
        &mut self,
        session_id: &str,
        payload: &NativeTransferPayload,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let target_uri = c_string(&payload.target_uri)?;
        let attended_call_id = optional_c_string(payload.attended_call_id.as_deref())?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_transfer_call(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                target_uri.as_ptr(),
                attended_call_id
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to transfer SIP call."))
        }
    }

    fn play_prompt(
        &mut self,
        session_id: &str,
        payload: &NativePromptPayload,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let prompt_id = c_string(&payload.prompt_id)?;
        let media_uri = optional_c_string(payload.media_uri.as_deref())?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_play_prompt(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                prompt_id.as_ptr(),
                media_uri
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to play SIP prompt."))
        }
    }

    fn start_recording(
        &mut self,
        session_id: &str,
        payload: &NativeRecordingPayload,
    ) -> Result<String, String> {
        let session_id = c_string(session_id)?;
        let recording_id = c_string(&payload.recording_id)?;
        let destination_uri = optional_c_string(payload.destination_uri.as_deref())?;
        let mut storage_uri = [0 as c_char; STORAGE_BUFFER_LEN];
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_start_recording(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                recording_id.as_ptr(),
                destination_uri
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                storage_uri.as_mut_ptr(),
                storage_uri.len(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to start SIP recording."));
        }
        Ok(read_fixed_c_string(&storage_uri).unwrap_or_default())
    }

    fn send_to_voicemail(
        &mut self,
        session_id: &str,
        payload: &NativeVoicemailPayload,
    ) -> Result<String, String> {
        let session_id = c_string(session_id)?;
        let mailbox = c_string(&payload.mailbox)?;
        let mut storage_uri = [0 as c_char; STORAGE_BUFFER_LEN];
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_send_to_voicemail(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                mailbox.as_ptr(),
                storage_uri.as_mut_ptr(),
                storage_uri.len(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to queue SIP voicemail."));
        }
        Ok(read_fixed_c_string(&storage_uri).unwrap_or_default())
    }

    fn attach_media_app(
        &mut self,
        session_id: &str,
        payload: &NativeMediaAppPayload,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let media_app_id = c_string(&payload.media_app_id)?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_attach_media_app(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                media_app_id.as_ptr(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to attach SIP media app."))
        }
    }

    fn detach_media_app(&mut self, session_id: &str) -> Result<(), String> {
        self.with_session_command(
            session_id,
            dart_edge_sip_bridge_detach_media_app,
            "Failed to detach SIP media app.",
        )
    }

    fn poll_media_frame(
        &mut self,
        session_id: &str,
    ) -> Result<Option<dart_edge_sip_audio_frame>, String> {
        let session_id = c_string(session_id)?;
        let mut bytes = vec![0_u8; 4096];
        let mut bytes_written = 0_usize;
        let mut sample_rate_hz = 0_u32;
        let mut channels = 0_u32;
        let mut frame_duration_ms = 0_u32;
        let mut sequence = 0_u64;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_read_media_frame(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                bytes.as_mut_ptr(),
                bytes.len(),
                &mut bytes_written,
                &mut sample_rate_hz,
                &mut channels,
                &mut frame_duration_ms,
                &mut sequence,
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if !ok {
            return Err(error.message("Failed to read SIP media frame."));
        }
        if bytes_written == 0 {
            return Ok(None);
        }

        bytes.truncate(bytes_written);
        Ok(Some(dart_edge_sip_audio_frame {
            bytes: into_native_owned_bytes(bytes),
            encoding: 0,
            sample_rate_hz,
            channels,
            frame_duration_ms,
            sequence,
        }))
    }

    fn play_media_copy(
        &mut self,
        session_id: &str,
        bytes: &[u8],
        sample_rate_hz: u32,
        channels: u32,
        frame_duration_ms: u32,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            dart_edge_sip_bridge_play_raw_audio(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                bytes.as_ptr(),
                bytes.len(),
                sample_rate_hz,
                channels,
                frame_duration_ms,
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message("Failed to play SIP media audio."))
        }
    }

    fn clear_media_playback(&mut self, session_id: &str) -> Result<(), String> {
        self.with_session_command(
            session_id,
            dart_edge_sip_bridge_clear_raw_audio,
            "Failed to clear SIP media playback.",
        )
    }

    fn poll_event(&mut self) -> Option<Value> {
        let mut event = dart_edge_sip_bridge_event::default();
        let has_event = unsafe { dart_edge_sip_bridge_poll_event(self.raw.as_ptr(), &mut event) };
        if !has_event {
            return None;
        }
        Some(bridge_event_to_json(&event))
    }

    fn with_session_command(
        &mut self,
        session_id: &str,
        command: unsafe extern "C" fn(
            *mut dart_edge_sip_bridge_runtime,
            *const c_char,
            *mut c_char,
            usize,
        ) -> bool,
        context: &str,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            command(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message(context))
        }
    }

    fn with_status_command(
        &mut self,
        session_id: &str,
        payload: &NativeStatusPayload,
        command: unsafe extern "C" fn(
            *mut dart_edge_sip_bridge_runtime,
            *const c_char,
            u32,
            *const c_char,
            *mut c_char,
            usize,
        ) -> bool,
        context: &str,
    ) -> Result<(), String> {
        let session_id = c_string(session_id)?;
        let reason = optional_c_string(payload.reason.as_deref())?;
        let mut error = ErrorBuffer::new();
        let ok = unsafe {
            command(
                self.raw.as_ptr(),
                session_id.as_ptr(),
                payload.status.unwrap_or(200),
                reason
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                error.as_mut_ptr(),
                error.len(),
            )
        };
        if ok {
            Ok(())
        } else {
            Err(error.message(context))
        }
    }
}

impl Drop for PjsipRuntime {
    fn drop(&mut self) {
        unsafe {
            dart_edge_sip_bridge_runtime_destroy(self.raw.as_ptr());
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_native_abi_version() -> i32 {
    DART_EDGE_SIP_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_create(config_json: *const c_char) -> i64 {
    let Some(config_json) = (unsafe { read_c_string(config_json) }) else {
        set_last_error("Missing SIP server config payload.");
        return 0;
    };

    let config = match serde_json::from_str::<NativeSipServerConfig>(&config_json) {
        Ok(config) => config,
        Err(error) => {
            set_last_error(format!("Invalid SIP server config: {error}"));
            return 0;
        }
    };
    if let Err(error) = validate_config(&config) {
        set_last_error(error);
        return 0;
    }

    let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
    SERVERS.lock().unwrap().insert(
        handle,
        NativeSipServer {
            config,
            runtime: None,
            started: false,
        },
    );
    clear_last_error();
    handle
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_start(handle: i64) -> bool {
    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_sip handle.");
        return false;
    };

    if server.started {
        clear_last_error();
        return true;
    }

    match PjsipRuntime::from_config(&server.config) {
        Ok(runtime) => {
            server.runtime = Some(runtime);
            server.started = true;
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
pub extern "C" fn dart_edge_sip_stop(handle: i64) -> bool {
    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_sip handle.");
        return false;
    };

    if !server.started {
        clear_last_error();
        return true;
    }

    let result = match server.runtime.take() {
        Some(mut runtime) => runtime.stop(),
        None => Ok(()),
    };
    match result {
        Ok(()) => {
            server.started = false;
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
pub extern "C" fn dart_edge_sip_dispose(handle: i64) {
    SERVERS.lock().unwrap().remove(&handle);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_issue_command(
    handle: i64,
    command_json: *const c_char,
) -> *mut c_char {
    let Some(command_json) = (unsafe { read_c_string(command_json) }) else {
        set_last_error("Missing dart_edge_sip command payload.");
        return std::ptr::null_mut();
    };

    let command = match serde_json::from_str::<NativeCommand>(&command_json) {
        Ok(command) => command,
        Err(error) => {
            set_last_error(format!("Invalid dart_edge_sip command: {error}"));
            return std::ptr::null_mut();
        }
    };

    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_sip handle.");
        return std::ptr::null_mut();
    };
    let Some(runtime) = server.runtime.as_mut() else {
        set_last_error("dart_edge_sip is not started.");
        return std::ptr::null_mut();
    };

    let NativeCommand {
        kind,
        session_id,
        payload,
        request,
    } = command;
    let session_id = session_id.as_deref();

    let result = match kind.as_str() {
        "originateCall" => parse_request::<NativeOriginateRequest>(request)
            .and_then(|request| runtime.originate_call(&request))
            .map(|session_id| json!({ "ok": true, "sessionId": session_id })),
        "originateEndpointCall" => parse_request::<NativeEndpointCallRequest>(request)
            .and_then(|request| runtime.originate_endpoint_call(&request))
            .map(|session_id| json!({ "ok": true, "sessionId": session_id })),
        "registeredEndpoints" => Ok(json!({
            "ok": true,
            "endpoints": runtime.registered_endpoints(),
        })),
        "addTrunk" => parse_payload::<NativeTrunkPayload>(payload)
            .and_then(|payload| {
                validate_trunk_config(&payload.trunk)?;
                if server
                    .config
                    .trunks
                    .iter()
                    .any(|trunk| trunk.id == payload.trunk.id)
                {
                    return Err(format!("Duplicate SIP trunk ID '{}'.", payload.trunk.id));
                }
                runtime.add_trunk(&payload.trunk)?;
                server.config.trunks.push(payload.trunk);
                Ok(())
            })
            .map(|()| json!({ "ok": true })),
        "updateTrunk" => parse_payload::<NativeUpdateTrunkPayload>(payload)
            .and_then(|payload| {
                validate_trunk_config(&payload.trunk)?;
                let Some(index) = server
                    .config
                    .trunks
                    .iter()
                    .position(|trunk| trunk.id == payload.trunk_id)
                else {
                    return Err(format!("Unknown SIP trunk '{}'.", payload.trunk_id));
                };
                if server
                    .config
                    .trunks
                    .iter()
                    .enumerate()
                    .any(|(other_index, trunk)| {
                        other_index != index && trunk.id == payload.trunk.id
                    })
                {
                    return Err(format!("Duplicate SIP trunk ID '{}'.", payload.trunk.id));
                }
                runtime.update_trunk(&payload.trunk_id, &payload.trunk)?;
                server.config.trunks[index] = payload.trunk;
                Ok(())
            })
            .map(|()| json!({ "ok": true })),
        "removeTrunk" => parse_payload::<NativeTrunkIdPayload>(payload)
            .and_then(|payload| {
                let Some(index) = server
                    .config
                    .trunks
                    .iter()
                    .position(|trunk| trunk.id == payload.trunk_id)
                else {
                    return Err(format!("Unknown SIP trunk '{}'.", payload.trunk_id));
                };
                runtime.remove_trunk(&payload.trunk_id)?;
                server.config.trunks.remove(index);
                Ok(())
            })
            .map(|()| json!({ "ok": true })),
        "setTrunkRegistration" => parse_payload::<NativeTrunkRegistrationPayload>(payload)
            .and_then(|payload| runtime.set_trunk_registration(&payload.trunk_id, payload.enabled))
            .map(|()| json!({ "ok": true })),
        "answer" => parse_payload::<NativeStatusPayload>(payload)
            .and_then(|payload| runtime.answer_call(required_session_id(session_id)?, &payload))
            .map(|()| json!({ "ok": true })),
        "reject" => parse_payload::<NativeStatusPayload>(payload)
            .and_then(|payload| runtime.reject_call(required_session_id(session_id)?, &payload))
            .map(|()| json!({ "ok": true })),
        "bridge" => parse_payload::<NativeBridgePayload>(payload)
            .and_then(|payload| runtime.bridge_calls(required_session_id(session_id)?, &payload))
            .map(|()| json!({ "ok": true })),
        "routeToEndpoint" => parse_payload::<NativeRouteEndpointPayload>(payload)
            .and_then(|payload| {
                runtime.route_call_to_endpoint(required_session_id(session_id)?, &payload)
            })
            .map(|routed_session_id| json!({ "ok": true, "sessionId": routed_session_id })),
        "routeToTrunk" => parse_payload::<NativeRouteTrunkPayload>(payload)
            .and_then(|payload| {
                runtime.route_call_to_trunk(required_session_id(session_id)?, &payload)
            })
            .map(|routed_session_id| json!({ "ok": true, "sessionId": routed_session_id })),
        "hold" => required_session_id(session_id)
            .and_then(|session_id| runtime.hold_call(session_id))
            .map(|()| json!({ "ok": true })),
        "resume" => required_session_id(session_id)
            .and_then(|session_id| runtime.resume_call(session_id))
            .map(|()| json!({ "ok": true })),
        "transfer" => parse_payload::<NativeTransferPayload>(payload)
            .and_then(|payload| runtime.transfer_call(required_session_id(session_id)?, &payload))
            .map(|()| json!({ "ok": true })),
        "playPrompt" => parse_payload::<NativePromptPayload>(payload)
            .and_then(|payload| runtime.play_prompt(required_session_id(session_id)?, &payload))
            .map(|()| json!({ "ok": true })),
        "startRecording" => parse_payload::<NativeRecordingPayload>(payload)
            .and_then(|payload| runtime.start_recording(required_session_id(session_id)?, &payload))
            .map(|storage_uri| json!({ "ok": true, "storageUri": storage_uri })),
        "sendToVoicemail" => parse_payload::<NativeVoicemailPayload>(payload)
            .and_then(|payload| {
                runtime.send_to_voicemail(required_session_id(session_id)?, &payload)
            })
            .map(|storage_uri| json!({ "ok": true, "storageUri": storage_uri })),
        "attachMediaApp" => parse_payload::<NativeMediaAppPayload>(payload)
            .and_then(|payload| {
                runtime.attach_media_app(required_session_id(session_id)?, &payload)
            })
            .map(|()| json!({ "ok": true })),
        "detachMediaApp" => required_session_id(session_id)
            .and_then(|session_id| runtime.detach_media_app(session_id))
            .map(|()| json!({ "ok": true })),
        "hangup" => parse_payload::<NativeStatusPayload>(payload)
            .and_then(|payload| runtime.hangup_call(required_session_id(session_id)?, &payload))
            .map(|()| json!({ "ok": true })),
        value => Err(format!("Unsupported dart_edge_sip command '{value}'.")),
    };

    match result {
        Ok(result) => {
            clear_last_error();
            encode_json(result)
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_poll_event(handle: i64) -> *mut c_char {
    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        return std::ptr::null_mut();
    };
    let Some(runtime) = server.runtime.as_mut() else {
        return std::ptr::null_mut();
    };

    match runtime.poll_event() {
        Some(event) => {
            clear_last_error();
            encode_json(event)
        }
        None => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_take_last_error() -> *mut c_char {
    let error = LAST_ERROR.lock().unwrap().take();
    match error {
        Some(error) => error.into_raw(),
        None => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sip_poll_media_frame(
    handle: i64,
    session_id: *const c_char,
    frame_out: *mut dart_edge_sip_audio_frame,
) -> bool {
    if frame_out.is_null() {
        set_last_error("Missing dart_edge_sip media frame output buffer.");
        return false;
    }
    unsafe {
        *frame_out = dart_edge_sip_audio_frame::default();
    }

    let Some(session_id) = (unsafe { read_c_string(session_id) }) else {
        set_last_error("Missing SIP media session ID.");
        return false;
    };

    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_sip handle.");
        return false;
    };
    let Some(runtime) = server.runtime.as_mut() else {
        set_last_error("dart_edge_sip is not started.");
        return false;
    };

    match runtime.poll_media_frame(&session_id) {
        Ok(Some(frame)) => {
            unsafe {
                *frame_out = frame;
            }
            clear_last_error();
            true
        }
        Ok(None) => {
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
pub extern "C" fn dart_edge_sip_play_media_copy(
    handle: i64,
    session_id: *const c_char,
    bytes: *const u8,
    len: isize,
    sample_rate_hz: u32,
    channels: u32,
    frame_duration_ms: u32,
) -> bool {
    let Some(session_id) = (unsafe { read_c_string(session_id) }) else {
        set_last_error("Missing SIP media session ID.");
        return false;
    };
    let Some(bytes) = (unsafe { read_byte_slice(bytes, len) }) else {
        set_last_error("Missing SIP media audio bytes.");
        return false;
    };

    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_sip handle.");
        return false;
    };
    let Some(runtime) = server.runtime.as_mut() else {
        set_last_error("dart_edge_sip is not started.");
        return false;
    };

    match runtime.play_media_copy(
        &session_id,
        bytes,
        sample_rate_hz,
        channels,
        frame_duration_ms,
    ) {
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
pub extern "C" fn dart_edge_sip_play_media_owned(
    handle: i64,
    session_id: *const c_char,
    bytes: NativeOwnedBytes,
    sample_rate_hz: u32,
    channels: u32,
    frame_duration_ms: u32,
) -> bool {
    let result = (|| {
        let Some(session_id) = (unsafe { read_c_string(session_id) }) else {
            return Err("Missing SIP media session ID.".to_string());
        };
        let Some(bytes) = (unsafe { read_byte_slice(bytes.ptr.cast_const(), bytes.len) }) else {
            return Err("Missing SIP media audio bytes.".to_string());
        };

        let mut servers = SERVERS.lock().unwrap();
        let Some(server) = servers.get_mut(&handle) else {
            return Err("Unknown dart_edge_sip handle.".to_string());
        };
        let Some(runtime) = server.runtime.as_mut() else {
            return Err("dart_edge_sip is not started.".to_string());
        };

        runtime.play_media_copy(
            &session_id,
            bytes,
            sample_rate_hz,
            channels,
            frame_duration_ms,
        )
    })();
    unsafe {
        free_owned_bytes(bytes);
    }

    match result {
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
pub extern "C" fn dart_edge_sip_clear_media_playback(
    handle: i64,
    session_id: *const c_char,
) -> bool {
    let Some(session_id) = (unsafe { read_c_string(session_id) }) else {
        set_last_error("Missing SIP media session ID.");
        return false;
    };

    let mut servers = SERVERS.lock().unwrap();
    let Some(server) = servers.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_sip handle.");
        return false;
    };
    let Some(runtime) = server.runtime.as_mut() else {
        set_last_error("dart_edge_sip is not started.");
        return false;
    };

    match runtime.clear_media_playback(&session_id) {
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
pub extern "C" fn dart_edge_sip_free_owned_bytes(value: NativeOwnedBytes) {
    unsafe {
        free_owned_bytes(value);
    }
}

fn validate_config(config: &NativeSipServerConfig) -> Result<(), String> {
    if config.engine.kind != "pjsip" {
        return Err(format!(
            "dart_edge_sip only supports the 'pjsip' engine, received '{}'.",
            config.engine.kind
        ));
    }
    if config.engine.license_mode != "gpl" && config.engine.license_mode != "commercial" {
        return Err(format!(
            "Unsupported PJSIP license mode '{}'.",
            config.engine.license_mode
        ));
    }
    if config.engine.max_calls == 0 {
        return Err("PJSIP maxCalls must be greater than zero.".to_string());
    }
    if config.engine.worker_threads == 0 {
        return Err("PJSIP workerThreads must be greater than zero.".to_string());
    }
    if config.engine.max_registrations == 0 {
        return Err("PJSIP maxRegistrations must be greater than zero.".to_string());
    }
    if config.engine.max_conference_ports == 0 {
        return Err("PJSIP maxConferencePorts must be greater than zero.".to_string());
    }
    if config.transports.is_empty() {
        return Err("At least one SIP transport binding is required.".to_string());
    }
    if config.media.rtp_start_port > config.media.rtp_end_port {
        return Err("media.rtpStartPort must not be greater than media.rtpEndPort.".to_string());
    }
    if config.recordings.enabled
        && config
            .recordings
            .directory
            .as_deref()
            .unwrap_or("")
            .is_empty()
    {
        return Err(
            "Recording storage is enabled but no recording directory was configured.".to_string(),
        );
    }
    if config.voicemail.enabled
        && config
            .voicemail
            .directory
            .as_deref()
            .unwrap_or("")
            .is_empty()
    {
        return Err(
            "Voicemail storage is enabled but no voicemail directory was configured.".to_string(),
        );
    }

    let mut trunk_ids = HashSet::new();
    for trunk in &config.trunks {
        if !trunk_ids.insert(trunk.id.clone()) {
            return Err(format!("Duplicate SIP trunk ID '{}'.", trunk.id));
        }
        validate_trunk_config(trunk)?;
    }

    let mut endpoint_ids = HashSet::new();
    for endpoint in &config.endpoints {
        if !endpoint_ids.insert(endpoint.id.clone()) {
            return Err(format!("Duplicate SIP endpoint ID '{}'.", endpoint.id));
        }
        if endpoint.username.is_empty() || endpoint.password.is_empty() {
            return Err(format!(
                "SIP endpoint '{}' requires non-empty username and password.",
                endpoint.id
            ));
        }
    }

    let mut realm_keys = HashSet::new();
    for realm in &config.realms {
        let key = format!("{}::{}", realm.domain, realm.realm);
        if !realm_keys.insert(key) {
            return Err(format!(
                "Duplicate SIP realm mapping for domain '{}' and realm '{}'.",
                realm.domain, realm.realm
            ));
        }
    }

    let _ = (
        &config.server_name,
        config.media.enable_dtmf_detection,
        config.features.registrar,
        config.features.authentication,
        config.features.bridging,
        config.features.transfers,
        config.features.ivr,
        config.features.recording,
        config.features.voicemail,
        config.recordings.retention_days,
    );
    for endpoint in &config.endpoints {
        let _ = (
            &endpoint.extension,
            &endpoint.realm,
            &endpoint.display_name,
            endpoint.allow_registrations,
        );
    }
    for realm in &config.realms {
        let _ = realm.require_authentication;
    }

    Ok(())
}

fn validate_trunk_config(trunk: &NativeSipTrunkConfig) -> Result<(), String> {
    if trunk.id.is_empty() {
        return Err("SIP trunk requires a non-empty id.".to_string());
    }
    if trunk.server_uri.is_empty() {
        return Err(format!("SIP trunk '{}' requires a serverUri.", trunk.id));
    }
    match trunk.direction.as_str() {
        "inbound" | "outbound" | "bidirectional" => Ok(()),
        value => Err(format!(
            "Unsupported SIP trunk direction '{}' for trunk '{}'.",
            value, trunk.id
        )),
    }
}

fn parse_payload<T>(payload: Option<Value>) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    serde_json::from_value(payload.unwrap_or_else(|| json!({})))
        .map_err(|error| format!("Invalid dart_edge_sip command payload: {error}"))
}

fn parse_request<T>(request: Option<Value>) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    let Some(request) = request else {
        return Err("Missing dart_edge_sip request payload.".to_string());
    };
    serde_json::from_value(request)
        .map_err(|error| format!("Invalid dart_edge_sip request payload: {error}"))
}

fn required_session_id(session_id: Option<&str>) -> Result<&str, String> {
    session_id.ok_or_else(|| "Missing sessionId.".to_string())
}

fn bridge_event_to_json(event: &dart_edge_sip_bridge_event) -> Value {
    match event.kind {
        BRIDGE_EVENT_REGISTRATION => {
            let mut json = serde_json::Map::new();
            json.insert(
                "category".to_string(),
                Value::String("registration".to_string()),
            );
            json.insert(
                "endpointId".to_string(),
                Value::String(string_or_empty(&event.endpoint_id)),
            );
            json.insert(
                "state".to_string(),
                Value::String(
                    match event.registration_state {
                        BRIDGE_REGISTRATION_REGISTERED => "registered",
                        BRIDGE_REGISTRATION_UNREGISTERED => "unregistered",
                        BRIDGE_REGISTRATION_AUTHENTICATION_FAILED => "authenticationFailed",
                        _ => "unregistered",
                    }
                    .to_string(),
                ),
            );
            maybe_insert_string(&mut json, "contactUri", &event.contact_uri);
            if event.expires_at_epoch_seconds > 0 {
                json.insert(
                    "metadata".to_string(),
                    json!({
                        "expiresAtEpochSeconds": event.expires_at_epoch_seconds,
                    }),
                );
            }
            Value::Object(json)
        }
        BRIDGE_EVENT_TRUNK => {
            let mut json = serde_json::Map::new();
            json.insert("category".to_string(), Value::String("trunk".to_string()));
            json.insert(
                "trunkId".to_string(),
                Value::String(string_or_empty(&event.trunk_id)),
            );
            json.insert(
                "state".to_string(),
                Value::String(
                    match event.trunk_state {
                        BRIDGE_TRUNK_CONNECTED => "connected",
                        BRIDGE_TRUNK_DISCONNECTED => "disconnected",
                        BRIDGE_TRUNK_FAILED => "failed",
                        _ => "failed",
                    }
                    .to_string(),
                ),
            );
            maybe_insert_string(&mut json, "details", &event.details);
            json.insert(
                "metadata".to_string(),
                json!({
                    "statusCode": event.status_code,
                }),
            );
            Value::Object(json)
        }
        BRIDGE_EVENT_RECORDING => {
            let mut json = serde_json::Map::new();
            json.insert(
                "category".to_string(),
                Value::String("recording".to_string()),
            );
            json.insert(
                "callId".to_string(),
                Value::String(string_or_empty(&event.call_id)),
            );
            json.insert(
                "recordingId".to_string(),
                Value::String(string_or_empty(&event.recording_id)),
            );
            json.insert(
                "state".to_string(),
                Value::String(
                    match event.recording_state {
                        BRIDGE_RECORDING_STARTED => "started",
                        BRIDGE_RECORDING_STOPPED => "stopped",
                        BRIDGE_RECORDING_COMPLETED => "completed",
                        _ => "completed",
                    }
                    .to_string(),
                ),
            );
            maybe_insert_string(&mut json, "storageUri", &event.storage_uri);
            Value::Object(json)
        }
        BRIDGE_EVENT_VOICEMAIL => {
            let mut json = serde_json::Map::new();
            json.insert(
                "category".to_string(),
                Value::String("voicemail".to_string()),
            );
            json.insert(
                "callId".to_string(),
                Value::String(string_or_empty(&event.call_id)),
            );
            json.insert(
                "mailbox".to_string(),
                Value::String(string_or_empty(&event.mailbox)),
            );
            json.insert(
                "state".to_string(),
                Value::String(
                    match event.voicemail_state {
                        BRIDGE_VOICEMAIL_QUEUED => "queued",
                        BRIDGE_VOICEMAIL_STORED => "stored",
                        BRIDGE_VOICEMAIL_FAILED => "failed",
                        _ => "failed",
                    }
                    .to_string(),
                ),
            );
            maybe_insert_string(&mut json, "messageId", &event.message_id);
            maybe_insert_string(&mut json, "storageUri", &event.storage_uri);
            Value::Object(json)
        }
        _ => {
            let mut json = serde_json::Map::new();
            json.insert("category".to_string(), Value::String("call".to_string()));
            json.insert(
                "callId".to_string(),
                Value::String(string_or_empty(&event.call_id)),
            );
            json.insert(
                "direction".to_string(),
                Value::String(if event.call_direction == BRIDGE_DIRECTION_INBOUND {
                    "inbound".to_string()
                } else {
                    "outbound".to_string()
                }),
            );
            json.insert(
                "state".to_string(),
                Value::String(
                    match event.call_state {
                        BRIDGE_CALL_INVITING => "inviting",
                        BRIDGE_CALL_RINGING => "ringing",
                        BRIDGE_CALL_ESTABLISHED => "established",
                        BRIDGE_CALL_BRIDGED => "bridged",
                        BRIDGE_CALL_ON_HOLD => "onHold",
                        BRIDGE_CALL_TRANSFERRING => "transferring",
                        BRIDGE_CALL_REJECTED => "rejected",
                        BRIDGE_CALL_TERMINATED => "terminated",
                        _ => "terminated",
                    }
                    .to_string(),
                ),
            );
            maybe_insert_string(&mut json, "fromUri", &event.from_uri);
            maybe_insert_string(&mut json, "toUri", &event.to_uri);
            maybe_insert_string(&mut json, "relatedCallId", &event.related_call_id);
            maybe_insert_string(&mut json, "mediaAppId", &event.media_app_id);
            Value::Object(json)
        }
    }
}

fn maybe_insert_string<const N: usize>(
    map: &mut serde_json::Map<String, Value>,
    key: &str,
    value: &[c_char; N],
) {
    if let Some(value) = read_fixed_c_string(value) {
        if !value.is_empty() {
            map.insert(key.to_string(), Value::String(value));
        }
    }
}

fn string_or_empty<const N: usize>(value: &[c_char; N]) -> String {
    read_fixed_c_string(value).unwrap_or_default()
}

fn c_string(value: &str) -> Result<CString, String> {
    CString::new(value).map_err(|_| format!("String contains an interior NUL byte: {value:?}"))
}

fn optional_c_string(value: Option<&str>) -> Result<Option<CString>, String> {
    value
        .filter(|value| !value.is_empty())
        .map(c_string)
        .transpose()
}

fn read_fixed_c_string<const N: usize>(value: &[c_char; N]) -> Option<String> {
    if value.first().copied().unwrap_or_default() == 0 {
        return None;
    }
    let value = unsafe { CStr::from_ptr(value.as_ptr()) };
    Some(value.to_string_lossy().into_owned())
}

fn encode_json(value: Value) -> *mut c_char {
    match CString::new(value.to_string()) {
        Ok(value) => value.into_raw(),
        Err(_) => {
            set_last_error("Failed to encode dart_edge_sip JSON response.");
            std::ptr::null_mut()
        }
    }
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

fn set_last_error(message: impl Into<String>) {
    let message = message.into();
    *LAST_ERROR.lock().unwrap() = CString::new(message)
        .ok()
        .or_else(|| CString::new("dart_edge_sip native error").ok());
}

unsafe fn read_c_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }
    Some(
        unsafe { CStr::from_ptr(value) }
            .to_string_lossy()
            .into_owned(),
    )
}

unsafe fn read_byte_slice<'a>(value: *const u8, len: isize) -> Option<&'a [u8]> {
    if len < 0 {
        return None;
    }
    if len == 0 {
        return Some(&[]);
    }
    if value.is_null() {
        return None;
    }
    Some(unsafe { std::slice::from_raw_parts(value, len as usize) })
}

struct ErrorBuffer {
    bytes: [c_char; ERROR_BUFFER_LEN],
}

impl ErrorBuffer {
    fn new() -> Self {
        Self {
            bytes: [0; ERROR_BUFFER_LEN],
        }
    }

    fn as_mut_ptr(&mut self) -> *mut c_char {
        self.bytes.as_mut_ptr()
    }

    fn len(&self) -> usize {
        self.bytes.len()
    }

    fn message(&self, fallback: &str) -> String {
        read_fixed_c_string(&self.bytes).unwrap_or_else(|| fallback.to_string())
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct dart_edge_sip_audio_frame {
    pub bytes: NativeOwnedBytes,
    pub encoding: i32,
    pub sample_rate_hz: u32,
    pub channels: u32,
    pub frame_duration_ms: u32,
    pub sequence: u64,
}

impl Default for dart_edge_sip_audio_frame {
    fn default() -> Self {
        Self {
            bytes: NativeOwnedBytes::default(),
            encoding: 0,
            sample_rate_hz: 0,
            channels: 0,
            frame_duration_ms: 0,
            sequence: 0,
        }
    }
}

#[repr(C)]
struct dart_edge_sip_bridge_runtime {
    _private: [u8; 0],
}

#[repr(C)]
struct dart_edge_sip_bridge_config {
    max_calls: u32,
    worker_threads: u32,
    max_media_ports: u32,
    rtp_start_port: u32,
    rtp_end_port: u32,
    enable_ice: bool,
    enable_turn: bool,
    enable_tls: bool,
    enable_srtp: bool,
    enable_rport: bool,
    enable_registrar: bool,
    user_agent: *const c_char,
    external_address: *const c_char,
    recording_directory: *const c_char,
    voicemail_directory: *const c_char,
    default_greeting_uri: *const c_char,
}

#[repr(C)]
struct dart_edge_sip_bridge_transport_config {
    protocol: i32,
    host: *const c_char,
    port: u32,
    public_address: *const c_char,
    tls_profile: *const c_char,
}

#[repr(C)]
struct dart_edge_sip_bridge_trunk_config {
    id: *const c_char,
    server_uri: *const c_char,
    username: *const c_char,
    password: *const c_char,
    realm: *const c_char,
    direction: i32,
}

#[repr(C)]
struct dart_edge_sip_bridge_endpoint_config {
    id: *const c_char,
    extension: *const c_char,
    username: *const c_char,
    password: *const c_char,
    realm: *const c_char,
    display_name: *const c_char,
    allow_registrations: bool,
    require_authentication: bool,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct dart_edge_sip_bridge_registered_endpoint {
    endpoint_id: [c_char; 64],
    contact_uri: [c_char; 256],
    expires_at_epoch_seconds: u64,
}

impl Default for dart_edge_sip_bridge_registered_endpoint {
    fn default() -> Self {
        unsafe { std::mem::zeroed() }
    }
}

#[repr(C)]
struct dart_edge_sip_bridge_event {
    kind: i32,
    call_direction: i32,
    call_state: i32,
    registration_state: i32,
    trunk_state: i32,
    recording_state: i32,
    voicemail_state: i32,
    status_code: i32,
    expires_at_epoch_seconds: u64,
    call_id: [c_char; 64],
    related_call_id: [c_char; 64],
    endpoint_id: [c_char; 64],
    trunk_id: [c_char; 64],
    recording_id: [c_char; 128],
    mailbox: [c_char; 128],
    message_id: [c_char; 128],
    from_uri: [c_char; 256],
    to_uri: [c_char; 256],
    contact_uri: [c_char; 256],
    media_app_id: [c_char; 128],
    storage_uri: [c_char; 1024],
    details: [c_char; 256],
}

impl Default for dart_edge_sip_bridge_event {
    fn default() -> Self {
        unsafe { std::mem::zeroed() }
    }
}

unsafe extern "C" {
    fn dart_edge_sip_bridge_runtime_create(
        config: *const dart_edge_sip_bridge_config,
        error: *mut c_char,
        error_len: usize,
    ) -> *mut dart_edge_sip_bridge_runtime;

    fn dart_edge_sip_bridge_runtime_destroy(runtime: *mut dart_edge_sip_bridge_runtime);

    fn dart_edge_sip_bridge_add_transport(
        runtime: *mut dart_edge_sip_bridge_runtime,
        transport: *const dart_edge_sip_bridge_transport_config,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_add_trunk(
        runtime: *mut dart_edge_sip_bridge_runtime,
        trunk: *const dart_edge_sip_bridge_trunk_config,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_update_trunk(
        runtime: *mut dart_edge_sip_bridge_runtime,
        trunk_id: *const c_char,
        trunk: *const dart_edge_sip_bridge_trunk_config,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_remove_trunk(
        runtime: *mut dart_edge_sip_bridge_runtime,
        trunk_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_set_trunk_registration(
        runtime: *mut dart_edge_sip_bridge_runtime,
        trunk_id: *const c_char,
        enabled: bool,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_add_endpoint(
        runtime: *mut dart_edge_sip_bridge_runtime,
        endpoint: *const dart_edge_sip_bridge_endpoint_config,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_start(
        runtime: *mut dart_edge_sip_bridge_runtime,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_stop(
        runtime: *mut dart_edge_sip_bridge_runtime,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_originate_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        trunk_id: *const c_char,
        from_uri: *const c_char,
        to_uri: *const c_char,
        session_id: *mut c_char,
        session_id_len: usize,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_originate_endpoint_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        endpoint_id: *const c_char,
        from_uri: *const c_char,
        to_uri: *const c_char,
        session_id: *mut c_char,
        session_id_len: usize,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_route_call_to_endpoint(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        endpoint_id: *const c_char,
        routed_session_id: *mut c_char,
        routed_session_id_len: usize,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_route_call_to_trunk(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        trunk_id: *const c_char,
        target_uri: *const c_char,
        routed_session_id: *mut c_char,
        routed_session_id_len: usize,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_list_registered_endpoints(
        runtime: *mut dart_edge_sip_bridge_runtime,
        endpoints: *mut dart_edge_sip_bridge_registered_endpoint,
        endpoint_capacity: usize,
    ) -> usize;

    fn dart_edge_sip_bridge_answer_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        status: u32,
        reason: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_reject_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        status: u32,
        reason: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_hangup_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        status: u32,
        reason: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_bridge_calls(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        other_session_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_hold_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_resume_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_transfer_call(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        target_uri: *const c_char,
        attended_session_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_play_prompt(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        prompt_id: *const c_char,
        media_uri: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_start_recording(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        recording_id: *const c_char,
        destination_uri: *const c_char,
        storage_uri: *mut c_char,
        storage_uri_len: usize,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_send_to_voicemail(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        mailbox: *const c_char,
        storage_uri: *mut c_char,
        storage_uri_len: usize,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_poll_event(
        runtime: *mut dart_edge_sip_bridge_runtime,
        event_out: *mut dart_edge_sip_bridge_event,
    ) -> bool;

    fn dart_edge_sip_bridge_attach_media_app(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        media_app_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_detach_media_app(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_read_media_frame(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        buffer: *mut u8,
        buffer_len: usize,
        bytes_written: *mut usize,
        sample_rate_hz: *mut u32,
        channels: *mut u32,
        frame_duration_ms: *mut u32,
        sequence: *mut u64,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_play_raw_audio(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        bytes: *const u8,
        bytes_len: usize,
        sample_rate_hz: u32,
        channels: u32,
        frame_duration_ms: u32,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;

    fn dart_edge_sip_bridge_clear_raw_audio(
        runtime: *mut dart_edge_sip_bridge_runtime,
        session_id: *const c_char,
        error: *mut c_char,
        error_len: usize,
    ) -> bool;
}
