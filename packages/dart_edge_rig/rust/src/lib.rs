use futures::StreamExt;
use once_cell::sync::Lazy;
use rig::agent::MultiTurnStreamItem;
use rig::client::image_generation::ImageGenerationClient;
use rig::client::{CompletionClient, ProviderClient};
use rig::completion::{Chat, CompletionModel, GetTokenUsage, Message, Prompt};
use rig::image_generation::ImageGenerationModel as _;
use rig::message::ReasoningContent;
use rig::prelude::TranscriptionClient;
use rig::providers::gemini::interactions_api::{
    AdditionalParameters, Content, CreateInteractionRequest, FunctionResultContent,
    InteractionInput, InteractionSseEvent, TextContent, Tool, Turn,
};
use rig::providers::{gemini, openai};
use rig::streaming::{
    StreamedAssistantContent, StreamedUserContent, StreamingChat, StreamingPrompt,
};
use rig::transcription::TranscriptionModel as _;
use serde_json::{Map, Value};
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::future::Future;
use std::os::raw::c_char;
use std::pin::Pin;
use std::ptr;
use std::slice;
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::{error::Error, fmt, mem};
use tokio::runtime::{Builder, Runtime};
use tokio::sync::{oneshot, watch};

const ABI_VERSION: i32 = 2;

type PromptFuture = Pin<Box<dyn Future<Output = Result<String, String>> + Send>>;
type PromptFunction = dyn Fn(Vec<Message>) -> PromptFuture + Send + Sync;
type StreamFuture = Pin<Box<dyn Future<Output = Result<String, String>> + Send>>;
type StreamFunction =
    dyn Fn(Vec<Message>, NativeRigStreamOptions, Arc<StreamRunState>) -> StreamFuture + Send + Sync;

const STREAM_EVENT_TEXT: i32 = 1;
const STREAM_EVENT_REASONING: i32 = 2;
const STREAM_EVENT_TOOL_CALL: i32 = 3;
const STREAM_EVENT_TOOL_CALL_DELTA: i32 = 4;
const STREAM_EVENT_TOOL_RESULT: i32 = 5;
const STREAM_EVENT_FINAL: i32 = 6;
const STREAM_EVENT_TOOL_EXECUTE_REQUEST: i32 = 7;

#[repr(C)]
pub struct NativeRigStringPair {
    pub key: *const c_char,
    pub value: *const c_char,
}

#[repr(C)]
pub struct NativeRigToolDefinition {
    pub name: *const c_char,
    pub description: *const c_char,
    pub parameters_json: *const c_char,
}

#[repr(C)]
pub struct NativeRigModelConfig {
    pub provider: *const c_char,
    pub model: *const c_char,
    pub api_key: *const c_char,
    pub base_url: *const c_char,
    pub additional_params_json: *const c_char,
}

#[repr(C)]
pub struct NativeRigTranscriptionRequest {
    pub data: *const u8,
    pub data_len: isize,
    pub filename: *const c_char,
    pub language: *const c_char,
    pub prompt: *const c_char,
    pub has_temperature: bool,
    pub temperature: f64,
    pub additional_params_json: *const c_char,
}

#[repr(C)]
pub struct NativeRigImageGenerationRequest {
    pub prompt: *const c_char,
    pub width: u32,
    pub height: u32,
    pub additional_params_json: *const c_char,
}

#[repr(C)]
pub struct NativeRigAgentConfig {
    pub provider: *const c_char,
    pub api: *const c_char,
    pub model: *const c_char,
    pub api_key: *const c_char,
    pub base_url: *const c_char,
    pub preamble: *const c_char,
    pub name: *const c_char,
    pub has_temperature: bool,
    pub temperature: f64,
    pub has_max_tokens: bool,
    pub max_tokens: u64,
    pub max_turns: isize,
    pub output_schema_json: *const c_char,
    pub additional_params_json: *const c_char,
    pub tools: *const NativeRigToolDefinition,
    pub tools_len: isize,
    pub headers: *const NativeRigStringPair,
    pub headers_len: isize,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NativeRigStreamOptions {
    pub max_turns: isize,
}

#[repr(C)]
pub struct NativeRigHandleResult {
    pub handle: i64,
    pub name: *mut c_char,
    pub error: *mut c_char,
}

#[repr(C)]
pub struct NativeRigPromptResult {
    pub output: *mut c_char,
    pub error: *mut c_char,
}

#[repr(C)]
pub struct NativeRigBytesResult {
    pub data: *mut u8,
    pub data_len: isize,
    pub error: *mut c_char,
}

#[repr(C)]
pub struct NativeRigStreamEvent {
    pub kind: i32,
    pub call_sequence: i64,
    pub text: *const c_char,
    pub id: *const c_char,
    pub internal_call_id: *const c_char,
    pub name: *const c_char,
    pub arguments_json: *const c_char,
    pub usage_json: *const c_char,
}

pub type NativeRigStreamCallback =
    Option<unsafe extern "C" fn(user_data: i64, event: *const NativeRigStreamEvent)>;

struct StoredAgent {
    name: String,
    prompt: Box<PromptFunction>,
    stream_prompt: Box<StreamFunction>,
}

#[derive(Clone)]
struct AgentSettings {
    temperature: Option<f64>,
    max_tokens: Option<u64>,
    default_max_turns: Option<usize>,
    output_schema: Option<schemars::Schema>,
    additional_params: Option<serde_json::Value>,
    tools: Vec<DartToolDefinition>,
}

#[derive(Clone)]
struct ModelSettings {
    provider: String,
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    additional_params: Option<serde_json::Value>,
}

struct TranscriptionInput {
    data: Vec<u8>,
    filename: String,
    language: Option<String>,
    prompt: Option<String>,
    temperature: Option<f64>,
    additional_params: Option<serde_json::Value>,
}

struct ImageGenerationInput {
    prompt: String,
    width: u32,
    height: u32,
    additional_params: Option<serde_json::Value>,
}

#[derive(Clone)]
struct DartToolDefinition {
    name: String,
    description: String,
    parameters: serde_json::Value,
}

struct StreamRunState {
    id: i64,
    callback: NativeRigStreamCallback,
    user_data: i64,
    canceled: AtomicBool,
    cancel_sender: watch::Sender<bool>,
    pending_tool_calls: Mutex<Vec<i64>>,
}

unsafe impl Send for StreamRunState {}
unsafe impl Sync for StreamRunState {}

impl StreamRunState {
    fn new(id: i64, callback: NativeRigStreamCallback, user_data: i64) -> Self {
        let (cancel_sender, _) = watch::channel(false);
        Self {
            id,
            callback,
            user_data,
            canceled: AtomicBool::new(false),
            cancel_sender,
            pending_tool_calls: Mutex::new(Vec::new()),
        }
    }

    fn is_canceled(&self) -> bool {
        self.canceled.load(Ordering::Acquire)
    }

    async fn cancelled(&self) {
        let mut receiver = self.cancel_sender.subscribe();
        if *receiver.borrow() {
            return;
        }
        while receiver.changed().await.is_ok() {
            if *receiver.borrow() {
                return;
            }
        }
    }

    fn cancel(&self, reason: impl Into<String>) {
        if !self.canceled.swap(true, Ordering::AcqRel) {
            let _ = self.cancel_sender.send(true);
        }
        self.cancel_pending_tool_calls(reason.into());
    }

    fn register_tool_call(
        &self,
        call_sequence: i64,
        sender: oneshot::Sender<PendingToolCompletion>,
    ) -> Result<(), String> {
        if self.is_canceled() {
            let _ = sender.send(PendingToolCompletion::Err("stream canceled".to_owned()));
            return Err("stream canceled".to_owned());
        }

        match PENDING_TOOL_CALLS.lock() {
            Ok(mut pending) => {
                pending.insert(
                    call_sequence,
                    PendingToolCall {
                        stream_id: self.id,
                        sender,
                    },
                );
            }
            Err(_) => return Err("tool call registry is poisoned".to_owned()),
        }

        match self.pending_tool_calls.lock() {
            Ok(mut pending) => {
                pending.push(call_sequence);
            }
            Err(_) => {
                complete_pending_tool_call(
                    call_sequence,
                    PendingToolCompletion::Err(
                        "stream pending tool registry is poisoned".to_owned(),
                    ),
                );
                return Err("stream pending tool registry is poisoned".to_owned());
            }
        }

        Ok(())
    }

    fn remove_tool_call(&self, call_sequence: i64) {
        if let Ok(mut pending) = self.pending_tool_calls.lock() {
            pending.retain(|value| *value != call_sequence);
        }
    }

    fn cancel_pending_tool_calls(&self, reason: String) {
        let call_sequences = match self.pending_tool_calls.lock() {
            Ok(mut pending) => pending.drain(..).collect::<Vec<_>>(),
            Err(_) => Vec::new(),
        };

        for call_sequence in call_sequences {
            complete_pending_tool_call(call_sequence, PendingToolCompletion::Err(reason.clone()));
        }
    }
}

enum PendingToolCompletion {
    Ok(String),
    Err(String),
}

struct PendingToolCall {
    stream_id: i64,
    sender: oneshot::Sender<PendingToolCompletion>,
}

tokio::task_local! {
    static CURRENT_STREAM_RUN: Arc<StreamRunState>;
}

static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Builder::new_multi_thread()
        .enable_all()
        .thread_name("dart-edge-rig")
        .build()
        .expect("failed to initialize dart_edge_rig tokio runtime")
});
static AGENTS: Lazy<Mutex<HashMap<i64, Arc<StoredAgent>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static NEXT_TOOL_CALL: AtomicI64 = AtomicI64::new(1);
static PENDING_TOOL_CALLS: Lazy<Mutex<HashMap<i64, PendingToolCall>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static STREAM_RUNS: Lazy<Mutex<HashMap<i64, Arc<StreamRunState>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_native_abi_version() -> i32 {
    ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_create_agent(
    config: *const NativeRigAgentConfig,
) -> *mut NativeRigHandleResult {
    if config.is_null() {
        return Box::into_raw(Box::new(handle_error("agent config is null")));
    }

    match create_agent(unsafe { &*config }) {
        Ok(agent) => {
            let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
            let name = agent.name.clone();
            match AGENTS.lock() {
                Ok(mut agents) => {
                    agents.insert(handle, Arc::new(agent));
                    Box::into_raw(Box::new(NativeRigHandleResult {
                        handle,
                        name: into_c_string(Some(name)),
                        error: ptr::null_mut(),
                    }))
                }
                Err(_) => Box::into_raw(Box::new(handle_error("agent registry is poisoned"))),
            }
        }
        Err(error) => Box::into_raw(Box::new(handle_error(error))),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_agent_prompt_message(
    agent_handle: i64,
    message_json: *const c_char,
) -> *mut NativeRigPromptResult {
    let prompt = match read_prompt_json(message_json) {
        Ok(prompt) => prompt,
        Err(error) => {
            return Box::into_raw(Box::new(prompt_error(error)));
        }
    };

    let agent = match AGENTS.lock() {
        Ok(agents) => agents.get(&agent_handle).cloned(),
        Err(_) => {
            return Box::into_raw(Box::new(prompt_error("agent registry is poisoned")));
        }
    };

    let Some(agent) = agent else {
        return Box::into_raw(Box::new(prompt_error("unknown Rig agent handle")));
    };

    match RUNTIME.block_on((agent.prompt)(prompt)) {
        Ok(output) => Box::into_raw(Box::new(NativeRigPromptResult {
            output: into_c_string(Some(output)),
            error: ptr::null_mut(),
        })),
        Err(error) => Box::into_raw(Box::new(prompt_error(error))),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_agent_stream_prompt_message(
    agent_handle: i64,
    message_json: *const c_char,
    options: *const NativeRigStreamOptions,
    callback: NativeRigStreamCallback,
    user_data: i64,
) -> *mut NativeRigPromptResult {
    let prompt = match read_prompt_json(message_json) {
        Ok(prompt) => prompt,
        Err(error) => {
            return Box::into_raw(Box::new(prompt_error(error)));
        }
    };

    let agent = match AGENTS.lock() {
        Ok(agents) => agents.get(&agent_handle).cloned(),
        Err(_) => {
            return Box::into_raw(Box::new(prompt_error("agent registry is poisoned")));
        }
    };

    let Some(agent) = agent else {
        return Box::into_raw(Box::new(prompt_error("unknown Rig agent handle")));
    };

    let options = if options.is_null() {
        NativeRigStreamOptions { max_turns: -1 }
    } else {
        unsafe { *options }
    };

    let stream_id = user_data;
    let run_state = Arc::new(StreamRunState::new(stream_id, callback, user_data));
    if stream_id != 0
        && let Ok(mut runs) = STREAM_RUNS.lock()
    {
        runs.insert(stream_id, run_state.clone());
    }

    let result = RUNTIME.block_on((agent.stream_prompt)(prompt, options, run_state.clone()));
    run_state.cancel_pending_tool_calls("stream finished".to_owned());
    if stream_id != 0
        && let Ok(mut runs) = STREAM_RUNS.lock()
    {
        runs.remove(&stream_id);
    }

    match result {
        Ok(output) => Box::into_raw(Box::new(NativeRigPromptResult {
            output: into_c_string(Some(output)),
            error: ptr::null_mut(),
        })),
        Err(error) => Box::into_raw(Box::new(prompt_error(error))),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_transcribe(
    config: *const NativeRigModelConfig,
    request: *const NativeRigTranscriptionRequest,
) -> *mut NativeRigPromptResult {
    if config.is_null() {
        return Box::into_raw(Box::new(prompt_error("model config is null")));
    }
    if request.is_null() {
        return Box::into_raw(Box::new(prompt_error("transcription request is null")));
    }

    let settings = match read_model_settings(unsafe { &*config }) {
        Ok(settings) => settings,
        Err(error) => {
            return Box::into_raw(Box::new(prompt_error(error)));
        }
    };
    let input = match read_transcription_input(unsafe { &*request }) {
        Ok(input) => input,
        Err(error) => {
            return Box::into_raw(Box::new(prompt_error(error)));
        }
    };

    match RUNTIME.block_on(transcribe(settings, input)) {
        Ok(text) => Box::into_raw(Box::new(NativeRigPromptResult {
            output: into_c_string(Some(text)),
            error: ptr::null_mut(),
        })),
        Err(error) => Box::into_raw(Box::new(prompt_error(error))),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_generate_image(
    config: *const NativeRigModelConfig,
    request: *const NativeRigImageGenerationRequest,
) -> *mut NativeRigBytesResult {
    if config.is_null() {
        return Box::into_raw(Box::new(bytes_error("model config is null")));
    }
    if request.is_null() {
        return Box::into_raw(Box::new(bytes_error("image generation request is null")));
    }

    let settings = match read_model_settings(unsafe { &*config }) {
        Ok(settings) => settings,
        Err(error) => {
            return Box::into_raw(Box::new(bytes_error(error)));
        }
    };
    let input = match read_image_generation_input(unsafe { &*request }) {
        Ok(input) => input,
        Err(error) => {
            return Box::into_raw(Box::new(bytes_error(error)));
        }
    };

    match RUNTIME.block_on(generate_image(settings, input)) {
        Ok(bytes) => bytes_result(bytes),
        Err(error) => Box::into_raw(Box::new(bytes_error(error))),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_complete_tool_call(
    call_sequence: i64,
    result: *const c_char,
    error: *const c_char,
) {
    let completion = match read_optional_string(error) {
        Some(error) => PendingToolCompletion::Err(error),
        None => PendingToolCompletion::Ok(read_optional_string(result).unwrap_or_default()),
    };

    complete_pending_tool_call(call_sequence, completion);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_cancel_stream(stream_id: i64) {
    let run = match STREAM_RUNS.lock() {
        Ok(runs) => runs.get(&stream_id).cloned(),
        Err(_) => None,
    };

    if let Some(run) = run {
        run.cancel("stream canceled");
    }
}

fn complete_pending_tool_call(call_sequence: i64, completion: PendingToolCompletion) {
    let pending_call = match PENDING_TOOL_CALLS.lock() {
        Ok(mut pending) => pending.remove(&call_sequence),
        Err(_) => None,
    };

    let Some(pending_call) = pending_call else {
        return;
    };

    if pending_call.stream_id != 0 {
        let run = match STREAM_RUNS.lock() {
            Ok(runs) => runs.get(&pending_call.stream_id).cloned(),
            Err(_) => None,
        };
        if let Some(run) = run {
            run.remove_tool_call(call_sequence);
        }
    }

    let _ = pending_call.sender.send(completion);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_dispose_handle(handle: i64) {
    if let Ok(mut agents) = AGENTS.lock() {
        agents.remove(&handle);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_free_handle_result(value: *mut NativeRigHandleResult) {
    if value.is_null() {
        return;
    }

    let value = unsafe { Box::from_raw(value) };
    free_string(value.name);
    free_string(value.error);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_free_prompt_result(value: *mut NativeRigPromptResult) {
    if value.is_null() {
        return;
    }

    let value = unsafe { Box::from_raw(value) };
    free_string(value.output);
    free_string(value.error);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_free_bytes_result(value: *mut NativeRigBytesResult) {
    if value.is_null() {
        return;
    }

    let value = unsafe { Box::from_raw(value) };
    if !value.data.is_null() && value.data_len > 0 {
        let slice = unsafe { slice::from_raw_parts_mut(value.data, value.data_len as usize) };
        unsafe {
            drop(Box::from_raw(slice as *mut [u8]));
        }
    }
    free_string(value.error);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_rig_free_stream_event(value: *mut NativeRigStreamEvent) {
    if value.is_null() {
        return;
    }

    let value = unsafe { Box::from_raw(value) };
    free_const_string(value.text);
    free_const_string(value.id);
    free_const_string(value.internal_call_id);
    free_const_string(value.name);
    free_const_string(value.arguments_json);
    free_const_string(value.usage_json);
}

fn create_agent(config: &NativeRigAgentConfig) -> Result<StoredAgent, String> {
    let provider = read_optional_string(config.provider)
        .unwrap_or_else(|| "openai".to_owned())
        .to_ascii_lowercase();

    let api = read_optional_string(config.api)
        .unwrap_or_else(|| "responses".to_owned())
        .to_ascii_lowercase();
    let model = read_required_string(config.model, "model")?;
    let api_key = read_optional_string(config.api_key);
    let base_url = read_optional_string(config.base_url);
    let preamble = read_optional_string(config.preamble);
    let configured_name = read_optional_string(config.name);
    let settings = read_agent_settings(config)?;

    match provider.as_str() {
        "openai" => create_openai_agent(
            api,
            model,
            api_key,
            base_url,
            preamble,
            configured_name,
            settings,
        ),
        "gemini" => create_gemini_agent(
            api,
            model,
            api_key,
            base_url,
            preamble,
            configured_name,
            settings,
        ),
        _ => Err(format!("unsupported Rig provider `{provider}`")),
    }
}

fn read_model_settings(config: &NativeRigModelConfig) -> Result<ModelSettings, String> {
    let provider = read_optional_string(config.provider)
        .unwrap_or_else(|| "openai".to_owned())
        .to_ascii_lowercase();
    let model = read_required_string(config.model, "model")?;
    let additional_params =
        read_json_value(config.additional_params_json, "additional_params_json")?;

    Ok(ModelSettings {
        provider,
        model,
        api_key: read_optional_string(config.api_key),
        base_url: read_optional_string(config.base_url),
        additional_params,
    })
}

fn read_transcription_input(
    request: &NativeRigTranscriptionRequest,
) -> Result<TranscriptionInput, String> {
    if request.data_len <= 0 {
        return Err("transcription data must not be empty.".to_owned());
    }
    if request.data.is_null() {
        return Err("transcription data pointer is null.".to_owned());
    }

    let data = unsafe { slice::from_raw_parts(request.data, request.data_len as usize) }.to_vec();
    let filename = read_optional_string(request.filename).unwrap_or_else(|| "audio".to_owned());
    if filename.is_empty() {
        return Err("transcription filename must not be empty.".to_owned());
    }
    let temperature = request.has_temperature.then_some(request.temperature);
    if let Some(temperature) = temperature
        && !temperature.is_finite()
    {
        return Err("transcription temperature must be finite.".to_owned());
    }

    Ok(TranscriptionInput {
        data,
        filename,
        language: read_optional_string(request.language),
        prompt: read_optional_string(request.prompt),
        temperature,
        additional_params: read_json_value(
            request.additional_params_json,
            "transcription additional_params_json",
        )?,
    })
}

fn read_image_generation_input(
    request: &NativeRigImageGenerationRequest,
) -> Result<ImageGenerationInput, String> {
    let prompt = read_required_string(request.prompt, "prompt")?;
    if prompt.is_empty() {
        return Err("image generation prompt must not be empty.".to_owned());
    }
    if request.width == 0 || request.height == 0 {
        return Err("image generation dimensions must be greater than zero.".to_owned());
    }

    Ok(ImageGenerationInput {
        prompt,
        width: request.width,
        height: request.height,
        additional_params: read_json_value(
            request.additional_params_json,
            "image generation additional_params_json",
        )?,
    })
}

fn read_agent_settings(config: &NativeRigAgentConfig) -> Result<AgentSettings, String> {
    let default_max_turns = if config.max_turns >= 0 {
        Some(config.max_turns as usize)
    } else {
        None
    };
    let additional_params =
        read_json_value(config.additional_params_json, "additional_params_json")?;
    let output_schema =
        match read_optional_string(config.output_schema_json) {
            Some(json) => Some(serde_json::from_str::<schemars::Schema>(&json).map_err(
                |error| format!("output_schema_json is not a valid JSON Schema: {error}"),
            )?),
            None => None,
        };
    let tools = read_tool_definitions(config.tools, config.tools_len)?;

    Ok(AgentSettings {
        temperature: config.has_temperature.then_some(config.temperature),
        max_tokens: config.has_max_tokens.then_some(config.max_tokens),
        default_max_turns,
        output_schema,
        additional_params,
        tools,
    })
}

fn read_json_value(
    pointer: *const c_char,
    name: &str,
) -> Result<Option<serde_json::Value>, String> {
    match read_optional_string(pointer) {
        Some(json) => serde_json::from_str(&json)
            .map(Some)
            .map_err(|error| format!("{name} is not valid JSON: {error}")),
        None => Ok(None),
    }
}

fn merge_optional_json(
    left: Option<serde_json::Value>,
    right: Option<serde_json::Value>,
) -> Option<serde_json::Value> {
    match (left, right) {
        (Some(mut left), Some(right)) => {
            merge_json_values(&mut left, right);
            Some(left)
        }
        (Some(left), None) => Some(left),
        (None, Some(right)) => Some(right),
        (None, None) => None,
    }
}

fn merge_json_values(left: &mut serde_json::Value, right: serde_json::Value) {
    match (left, right) {
        (serde_json::Value::Object(left), serde_json::Value::Object(right)) => {
            for (key, value) in right {
                match left.get_mut(&key) {
                    Some(existing) => merge_json_values(existing, value),
                    None => {
                        left.insert(key, value);
                    }
                }
            }
        }
        (left, right) => *left = right,
    }
}

fn read_tool_definitions(
    tools: *const NativeRigToolDefinition,
    len: isize,
) -> Result<Vec<DartToolDefinition>, String> {
    if len <= 0 || tools.is_null() {
        return Ok(vec![]);
    }

    let mut values = Vec::with_capacity(len as usize);
    for index in 0..len {
        let value = unsafe { &*tools.offset(index) };
        let name = read_required_string(value.name, "tool.name")?;
        let description = read_required_string(value.description, "tool.description")?;
        let parameters_json = read_required_string(value.parameters_json, "tool.parameters_json")?;
        let parameters = serde_json::from_str(&parameters_json)
            .map_err(|error| format!("tool `{name}` parameters_json is not valid JSON: {error}"))?;

        values.push(DartToolDefinition {
            name,
            description,
            parameters,
        });
    }
    Ok(values)
}

#[derive(serde::Deserialize)]
struct PromptEnvelope {
    messages: Vec<Message>,
}

fn read_prompt_json(message_json: *const c_char) -> Result<Vec<Message>, String> {
    let json = read_required_string(message_json, "message_json")?;
    let messages = if let Ok(envelope) = serde_json::from_str::<PromptEnvelope>(&json) {
        envelope.messages
    } else if let Ok(messages) = serde_json::from_str::<Vec<Message>>(&json) {
        messages
    } else if let Ok(message) = serde_json::from_str::<Message>(&json) {
        vec![message]
    } else {
        return Err("message_json is not a valid Rig prompt.".to_owned());
    };
    if messages.is_empty() {
        return Err("message_json prompt messages must not be empty.".to_owned());
    }
    Ok(messages)
}

fn split_prompt_messages(mut messages: Vec<Message>) -> Result<(Message, Vec<Message>), String> {
    let Some(prompt) = messages.pop() else {
        return Err("prompt messages must not be empty.".to_owned());
    };
    Ok((prompt, messages))
}

fn create_openai_agent(
    api: String,
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    preamble: Option<String>,
    configured_name: Option<String>,
    settings: AgentSettings,
) -> Result<StoredAgent, String> {
    match api.as_str() {
        "responses" => create_openai_responses_agent(
            model,
            api_key,
            base_url,
            preamble,
            configured_name,
            settings,
        ),
        "completions" | "chat_completions" | "chat-completions" => create_openai_completions_agent(
            model,
            api_key,
            base_url,
            preamble,
            configured_name,
            settings,
        ),
        _ => Err(format!("unsupported OpenAI API `{api}`")),
    }
}

fn create_gemini_agent(
    api: String,
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    preamble: Option<String>,
    configured_name: Option<String>,
    settings: AgentSettings,
) -> Result<StoredAgent, String> {
    match api.as_str() {
        "generate_content" | "generate-content" | "generatecontent" => {
            create_gemini_generate_content_agent(
                model,
                api_key,
                base_url,
                preamble,
                configured_name,
                settings,
            )
        }
        "interactions" => create_gemini_interactions_agent(
            model,
            api_key,
            base_url,
            preamble,
            configured_name,
            settings,
        ),
        _ => Err(format!("unsupported Gemini API `{api}`")),
    }
}

fn create_openai_responses_agent(
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    preamble: Option<String>,
    configured_name: Option<String>,
    settings: AgentSettings,
) -> Result<StoredAgent, String> {
    let client = openai_responses_client(api_key, base_url)?;

    let mut builder = client.agent(model.clone());
    if let Some(preamble) = preamble.as_deref() {
        builder = builder.preamble(preamble);
    }
    if let Some(name) = configured_name.as_deref() {
        builder = builder.name(name);
    }
    if let Some(temperature) = settings.temperature {
        builder = builder.temperature(temperature);
    }
    if let Some(max_tokens) = settings.max_tokens {
        builder = builder.max_tokens(max_tokens);
    }
    if let Some(default_max_turns) = settings.default_max_turns {
        builder = builder.default_max_turns(default_max_turns);
    }
    if let Some(output_schema) = settings.output_schema.clone() {
        builder = builder.output_schema_raw(output_schema);
    }
    if let Some(additional_params) = settings.additional_params.clone() {
        builder = builder.additional_params(additional_params);
    }
    let tools = dart_tools(settings.tools);
    let agent = build_agent(builder, tools);
    let name = configured_name.unwrap_or_else(|| format!("openai.responses.{model}"));

    Ok(stored_agent(name, agent))
}

fn create_openai_completions_agent(
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    preamble: Option<String>,
    configured_name: Option<String>,
    settings: AgentSettings,
) -> Result<StoredAgent, String> {
    let client = openai_completions_client(api_key, base_url)?;

    let mut builder = client.agent(model.clone());
    if let Some(preamble) = preamble.as_deref() {
        builder = builder.preamble(preamble);
    }
    if let Some(name) = configured_name.as_deref() {
        builder = builder.name(name);
    }
    if let Some(temperature) = settings.temperature {
        builder = builder.temperature(temperature);
    }
    if let Some(max_tokens) = settings.max_tokens {
        builder = builder.max_tokens(max_tokens);
    }
    if let Some(default_max_turns) = settings.default_max_turns {
        builder = builder.default_max_turns(default_max_turns);
    }
    if let Some(output_schema) = settings.output_schema.clone() {
        builder = builder.output_schema_raw(output_schema);
    }
    if let Some(additional_params) = settings.additional_params.clone() {
        builder = builder.additional_params(additional_params);
    }
    let tools = dart_tools(settings.tools);
    let agent = build_agent(builder, tools);
    let name = configured_name.unwrap_or_else(|| format!("openai.completions.{model}"));

    Ok(stored_agent(name, agent))
}

fn create_gemini_generate_content_agent(
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    preamble: Option<String>,
    configured_name: Option<String>,
    settings: AgentSettings,
) -> Result<StoredAgent, String> {
    let api_key = require_configured_api_key(api_key, "Gemini")?;
    let mut client_builder = gemini::Client::builder().api_key(&api_key);
    if let Some(base_url) = base_url.as_deref() {
        client_builder = client_builder.base_url(base_url);
    }
    let client = client_builder.build().map_err(|error| error.to_string())?;

    let mut builder = client.agent(model.clone());
    if let Some(preamble) = preamble.as_deref() {
        builder = builder.preamble(preamble);
    }
    if let Some(name) = configured_name.as_deref() {
        builder = builder.name(name);
    }
    if let Some(temperature) = settings.temperature {
        builder = builder.temperature(temperature);
    }
    if let Some(max_tokens) = settings.max_tokens {
        builder = builder.max_tokens(max_tokens);
    }
    if let Some(default_max_turns) = settings.default_max_turns {
        builder = builder.default_max_turns(default_max_turns);
    }
    if let Some(output_schema) = settings.output_schema {
        builder = builder.output_schema_raw(output_schema);
    }
    if let Some(additional_params) = settings.additional_params {
        builder = builder.additional_params(additional_params);
    }
    let tools = dart_tools(settings.tools);
    let agent = build_agent(builder, tools);
    let name = configured_name.unwrap_or_else(|| format!("gemini.generate_content.{model}"));

    Ok(stored_agent(name, agent))
}

fn create_gemini_interactions_agent(
    model: String,
    api_key: Option<String>,
    base_url: Option<String>,
    preamble: Option<String>,
    configured_name: Option<String>,
    settings: AgentSettings,
) -> Result<StoredAgent, String> {
    let api_key = require_configured_api_key(api_key, "Gemini")?;
    let mut client_builder = gemini::InteractionsClient::builder().api_key(&api_key);
    if let Some(base_url) = base_url.as_deref() {
        client_builder = client_builder.base_url(base_url);
    }
    let client = client_builder.build().map_err(|error| error.to_string())?;

    let mut builder = client.agent(model.clone());
    if let Some(preamble) = preamble.as_deref() {
        builder = builder.preamble(preamble);
    }
    if let Some(name) = configured_name.as_deref() {
        builder = builder.name(name);
    }
    if let Some(temperature) = settings.temperature {
        builder = builder.temperature(temperature);
    }
    if let Some(max_tokens) = settings.max_tokens {
        builder = builder.max_tokens(max_tokens);
    }
    if let Some(default_max_turns) = settings.default_max_turns {
        builder = builder.default_max_turns(default_max_turns);
    }
    if let Some(output_schema) = settings.output_schema.clone() {
        builder = builder.output_schema_raw(output_schema);
    }
    if let Some(additional_params) = settings.additional_params.clone() {
        builder = builder.additional_params(additional_params);
    }
    let stream_settings = settings.clone();
    let tools = dart_tools(settings.tools);
    let agent = build_agent(builder, tools);
    let name = configured_name.unwrap_or_else(|| format!("gemini.interactions.{model}"));

    Ok(stored_gemini_interactions_agent(
        name,
        model,
        preamble,
        client,
        agent,
        stream_settings,
    ))
}

async fn transcribe(settings: ModelSettings, input: TranscriptionInput) -> Result<String, String> {
    match settings.provider.as_str() {
        "openai" => transcribe_openai(settings, input).await,
        "gemini" => transcribe_gemini(settings, input).await,
        provider => Err(format!(
            "unsupported Rig transcription provider `{provider}`"
        )),
    }
}

async fn transcribe_openai(
    settings: ModelSettings,
    input: TranscriptionInput,
) -> Result<String, String> {
    let client = openai_responses_client(settings.api_key, settings.base_url)?;
    let model = client.transcription_model(settings.model);
    let mut builder = model
        .transcription_request()
        .data(input.data)
        .filename(Some(input.filename));
    if let Some(language) = input.language {
        builder = builder.language(language);
    }
    if let Some(prompt) = input.prompt {
        builder = builder.prompt(prompt);
    }
    if let Some(temperature) = input.temperature {
        builder = builder.temperature(temperature);
    }
    if let Some(params) = merge_optional_json(settings.additional_params, input.additional_params) {
        builder = builder.additional_params(params);
    }

    builder
        .send()
        .await
        .map(|response| response.text)
        .map_err(|error| error.to_string())
}

async fn transcribe_gemini(
    settings: ModelSettings,
    input: TranscriptionInput,
) -> Result<String, String> {
    let client = gemini_client(settings.api_key, settings.base_url)?;
    let model = client.transcription_model(settings.model);
    let mut builder = model
        .transcription_request()
        .data(input.data)
        .filename(Some(input.filename));
    if let Some(language) = input.language {
        builder = builder.language(language);
    }
    if let Some(prompt) = input.prompt {
        builder = builder.prompt(prompt);
    }
    if let Some(temperature) = input.temperature {
        builder = builder.temperature(temperature);
    }
    if let Some(params) = merge_optional_json(settings.additional_params, input.additional_params) {
        builder = builder.additional_params(params);
    }

    builder
        .send()
        .await
        .map(|response| response.text)
        .map_err(|error| error.to_string())
}

async fn generate_image(
    settings: ModelSettings,
    input: ImageGenerationInput,
) -> Result<Vec<u8>, String> {
    match settings.provider.as_str() {
        "openai" => generate_openai_image(settings, input).await,
        provider => Err(format!(
            "unsupported Rig image generation provider `{provider}`"
        )),
    }
}

async fn generate_openai_image(
    settings: ModelSettings,
    input: ImageGenerationInput,
) -> Result<Vec<u8>, String> {
    let client = openai_responses_client(settings.api_key, settings.base_url)?;
    let model = client.image_generation_model(settings.model);
    let mut builder = model
        .image_generation_request()
        .prompt(&input.prompt)
        .width(input.width)
        .height(input.height);
    if let Some(params) = merge_optional_json(settings.additional_params, input.additional_params) {
        builder = builder.additional_params(params);
    }

    builder
        .send()
        .await
        .map(|response| response.image)
        .map_err(|error| error.to_string())
}

fn openai_responses_client(
    api_key: Option<String>,
    base_url: Option<String>,
) -> Result<openai::Client, String> {
    match (api_key, base_url) {
        (None, None) => openai::Client::from_env().map_err(|error| error.to_string()),
        (api_key, base_url) => {
            let api_key = require_configured_api_key(api_key, "OpenAI")?;
            let mut client_builder = openai::Client::builder().api_key(&api_key);
            if let Some(base_url) = base_url.as_deref() {
                client_builder = client_builder.base_url(base_url);
            }
            client_builder.build().map_err(|error| error.to_string())
        }
    }
}

fn gemini_client(
    api_key: Option<String>,
    base_url: Option<String>,
) -> Result<gemini::Client, String> {
    let api_key = require_configured_api_key(api_key, "Gemini")?;
    let mut client_builder = gemini::Client::builder().api_key(&api_key);
    if let Some(base_url) = base_url.as_deref() {
        client_builder = client_builder.base_url(base_url);
    }
    client_builder.build().map_err(|error| error.to_string())
}

fn openai_completions_client(
    api_key: Option<String>,
    base_url: Option<String>,
) -> Result<openai::CompletionsClient, String> {
    match (api_key, base_url) {
        (None, None) => openai::CompletionsClient::from_env().map_err(|error| error.to_string()),
        (api_key, base_url) => {
            let api_key = require_configured_api_key(api_key, "OpenAI")?;
            let mut client_builder = openai::CompletionsClient::builder().api_key(&api_key);
            if let Some(base_url) = base_url.as_deref() {
                client_builder = client_builder.base_url(base_url);
            }
            client_builder.build().map_err(|error| error.to_string())
        }
    }
}

fn dart_tools(tools: Vec<DartToolDefinition>) -> Vec<Box<dyn rig::tool::ToolDyn>> {
    tools
        .into_iter()
        .map(|definition| Box::new(DartRigTool { definition }) as Box<dyn rig::tool::ToolDyn>)
        .collect()
}

fn build_agent<M>(
    builder: rig::agent::AgentBuilder<M>,
    tools: Vec<Box<dyn rig::tool::ToolDyn>>,
) -> Arc<rig::agent::Agent<M>>
where
    M: CompletionModel,
{
    if tools.is_empty() {
        Arc::new(builder.build())
    } else {
        Arc::new(builder.tools(tools).build())
    }
}

fn stored_gemini_interactions_agent(
    name: String,
    model: String,
    preamble: Option<String>,
    client: gemini::InteractionsClient,
    agent: Arc<rig::agent::Agent<gemini::interactions_api::InteractionsCompletionModel>>,
    settings: AgentSettings,
) -> StoredAgent {
    let prompt_agent = agent;
    let stream_client = client;

    StoredAgent {
        name,
        prompt: Box::new(move |prompt| {
            let agent = prompt_agent.clone();
            Box::pin(async move {
                let (prompt, mut history) = split_prompt_messages(prompt)?;
                if history.is_empty() {
                    agent
                        .prompt(prompt)
                        .await
                        .map_err(|error| error.to_string())
                } else {
                    agent
                        .chat(prompt, &mut history)
                        .await
                        .map_err(|error| error.to_string())
                }
            })
        }),
        stream_prompt: Box::new(move |prompt, options, run_state| {
            let client = stream_client.clone();
            let model = model.clone();
            let preamble = preamble.clone();
            let settings = settings.clone();
            Box::pin(async move {
                stream_gemini_interactions_prompt(
                    client, model, preamble, settings, prompt, options, run_state,
                )
                .await
            })
        }),
    }
}

#[derive(Default)]
struct PendingGeminiFunctionCall {
    name: Option<String>,
    id: Option<String>,
    arguments: Option<Value>,
}

async fn stream_gemini_interactions_prompt(
    client: gemini::InteractionsClient,
    model: String,
    preamble: Option<String>,
    settings: AgentSettings,
    prompt: Vec<Message>,
    options: NativeRigStreamOptions,
    run_state: Arc<StreamRunState>,
) -> Result<String, String> {
    let max_tool_turns = resolve_stream_max_turns(options, &settings);
    let max_model_turns = max_model_turns_for_tool_turns(max_tool_turns);

    let mut input = first_gemini_interactions_input(prompt)?;
    let mut previous_interaction_id = None;
    let mut final_output = String::new();
    let mut final_usage_json = "{}".to_owned();

    for turn in 0..max_model_turns {
        let request = build_gemini_interactions_request(
            model.clone(),
            input,
            preamble.clone(),
            &settings,
            previous_interaction_id.clone(),
        )?;

        let mut stream = tokio::select! {
            _ = run_state.cancelled() => return Err("stream canceled".to_owned()),
            stream = client.stream_interaction_events(request) => {
                stream.map_err(|error| error.to_string())?
            }
        };

        let mut pending_calls: HashMap<i32, PendingGeminiFunctionCall> = HashMap::new();
        let mut tool_results = Vec::new();
        let mut turn_output = String::new();

        loop {
            let event = tokio::select! {
                _ = run_state.cancelled() => return Err("stream canceled".to_owned()),
                event = stream.next() => event,
            };
            let Some(event) = event else {
                break;
            };
            match event.map_err(|error| error.to_string())? {
                InteractionSseEvent::ContentStart { index, content, .. } => {
                    match content {
                        Content::Text(TextContent { text, .. }) => {
                            if !text.is_empty() {
                                turn_output.push_str(&text);
                                emit_stream_event(
                                    &run_state,
                                    StreamEventFields::new(STREAM_EVENT_TEXT).text(text),
                                );
                            }
                        }
                        Content::FunctionCall(call) => {
                            let pending = pending_calls.entry(index).or_default();
                            pending.name = call.name;
                            pending.id = call.id;
                            pending.arguments = call.arguments;
                        }
                        Content::Thought(thought) => {
                            if let Some(summary) = thought.summary {
                                for content in summary {
                                    if let rig::providers::gemini::interactions_api::ThoughtSummaryContent::Text(text) = content {
                                        emit_stream_event(
                                            &run_state,
                                            StreamEventFields::new(STREAM_EVENT_REASONING)
                                                .name(Some("summary".to_owned()))
                                                .text(text.text),
                                        );
                                    }
                                }
                            }
                        }
                        _ => {}
                    }
                }
                InteractionSseEvent::ContentDelta { index, delta, .. } => {
                    match delta {
                        rig::providers::gemini::interactions_api::ContentDelta::Text(delta) => {
                            if let Some(text) = delta.text {
                                turn_output.push_str(&text);
                                emit_stream_event(
                                    &run_state,
                                    StreamEventFields::new(STREAM_EVENT_TEXT).text(text),
                                );
                            }
                        }
                        rig::providers::gemini::interactions_api::ContentDelta::ThoughtSummary(
                            delta,
                        ) => {
                            if let rig::providers::gemini::interactions_api::ThoughtSummaryContent::Text(text) =
                                delta.content
                            {
                                emit_stream_event(
                                    &run_state,
                                    StreamEventFields::new(STREAM_EVENT_REASONING)
                                        .name(Some("summary".to_owned()))
                                        .text(text.text),
                                );
                            }
                        }
                        rig::providers::gemini::interactions_api::ContentDelta::FunctionCall(
                            delta,
                        ) => {
                            let pending = pending_calls.entry(index).or_default();
                            if delta.name.is_some() {
                                pending.name = delta.name;
                            }
                            if delta.id.is_some() {
                                pending.id = delta.id;
                            }
                            if delta.arguments.is_some() {
                                pending.arguments = delta.arguments;
                            }
                        }
                        _ => {}
                    }
                }
                InteractionSseEvent::ContentStop { index, .. } => {
                    let Some(call) = pending_calls.remove(&index) else {
                        continue;
                    };
                    let Some(name) = call.name else {
                        continue;
                    };
                    let call_id = call.id.unwrap_or_else(|| name.clone());
                    let arguments = call.arguments.unwrap_or(Value::Object(Map::new()));
                    let arguments_json = arguments.to_string();

                    emit_stream_event(
                        &run_state,
                        StreamEventFields::new(STREAM_EVENT_TOOL_CALL)
                            .id(Some(call_id.clone()))
                            .name(Some(name.clone()))
                            .arguments_json(Some(arguments_json.clone())),
                    );

                    let result =
                        execute_dart_tool(run_state.clone(), name.clone(), arguments_json).await?;
                    emit_stream_event(
                        &run_state,
                        StreamEventFields::new(STREAM_EVENT_TOOL_RESULT)
                            .id(Some(call_id.clone()))
                            .name(Some(name.clone()))
                            .text(result.clone()),
                    );

                    let result_value = serde_json::from_str(&result).unwrap_or(Value::String(result));
                    tool_results.push(Content::FunctionResult(FunctionResultContent {
                        name: Some(name),
                        is_error: None,
                        result: Some(result_value),
                        call_id: Some(call_id),
                    }));
                }
                InteractionSseEvent::InteractionComplete { interaction, .. } => {
                    previous_interaction_id = if interaction.id.is_empty() {
                        previous_interaction_id
                    } else {
                        Some(interaction.id)
                    };
                    if let Some(usage) = interaction.usage
                        && let Some(usage) = usage.token_usage()
                    {
                        final_usage_json =
                            serde_json::to_string(&usage).unwrap_or_else(|_| "{}".to_owned());
                    }
                }
                InteractionSseEvent::Error { error, .. } => {
                    return Err(format!("{}: {}", error.code, error.message));
                }
                _ => {}
            }
        }

        if tool_results.is_empty() {
            final_output = turn_output;
            emit_stream_event(
                &run_state,
                StreamEventFields::new(STREAM_EVENT_FINAL)
                    .text(final_output.clone())
                    .usage_json(Some(final_usage_json)),
            );
            return Ok(final_output);
        }

        if turn + 1 >= max_model_turns {
            return Err(format!(
                "maximum tool-call turns exceeded: {max_tool_turns}"
            ));
        }

        input = InteractionInput::Contents(tool_results);
    }

    emit_stream_event(
        &run_state,
        StreamEventFields::new(STREAM_EVENT_FINAL)
            .text(final_output.clone())
            .usage_json(Some(final_usage_json)),
    );
    Ok(final_output)
}

fn resolve_stream_max_turns(options: NativeRigStreamOptions, settings: &AgentSettings) -> usize {
    if options.max_turns >= 0 {
        options.max_turns as usize
    } else {
        settings.default_max_turns.unwrap_or(8)
    }
}

fn max_model_turns_for_tool_turns(max_tool_turns: usize) -> usize {
    max_tool_turns.saturating_add(2)
}

fn first_gemini_interactions_input(prompt: Vec<Message>) -> Result<InteractionInput, String> {
    let turns = prompt
        .into_iter()
        .map(|message| Turn::try_from(message).map_err(|error| error.to_string()))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(InteractionInput::Turns(turns))
}

fn build_gemini_interactions_request(
    model: String,
    input: InteractionInput,
    preamble: Option<String>,
    settings: &AgentSettings,
    previous_interaction_id: Option<String>,
) -> Result<CreateInteractionRequest, String> {
    let raw_params = settings
        .additional_params
        .clone()
        .unwrap_or_else(|| Value::Object(Map::new()));
    let mut params: AdditionalParameters =
        serde_json::from_value(raw_params).map_err(|error| error.to_string())?;

    let mut generation_config = params.generation_config.take().unwrap_or_default();
    if let Some(temperature) = settings.temperature {
        generation_config.temperature = Some(temperature);
    }
    if let Some(max_tokens) = settings.max_tokens {
        generation_config.max_output_tokens = Some(max_tokens);
    }
    let generation_config = if generation_config.is_empty() {
        None
    } else {
        Some(generation_config)
    };

    let mut tools = settings
        .tools
        .iter()
        .map(|tool| {
            Tool::Function(rig::providers::gemini::interactions_api::FunctionTool {
                name: Some(tool.name.clone()),
                description: Some(tool.description.clone()),
                parameters: Some(tool.parameters.clone()),
            })
        })
        .collect::<Vec<_>>();
    if let Some(mut extra_tools) = params.tools.take() {
        tools.append(&mut extra_tools);
    }
    let tools = if tools.is_empty() { None } else { Some(tools) };

    let response_format = params.response_format.take();
    let response_mime_type = params.response_mime_type.take();
    if response_format.is_some() && response_mime_type.is_none() {
        return Err("response_mime_type is required when response_format is set".to_owned());
    }

    Ok(CreateInteractionRequest {
        model: if params.agent.is_some() {
            None
        } else {
            Some(model)
        },
        agent: params.agent.take(),
        input,
        system_instruction: preamble.or(params.system_instruction.take()),
        tools,
        response_format,
        response_mime_type,
        stream: Some(true),
        store: params.store.take(),
        background: params.background.take(),
        generation_config,
        agent_config: params.agent_config.take(),
        response_modalities: params.response_modalities.take(),
        previous_interaction_id: previous_interaction_id.or(params.previous_interaction_id.take()),
        additional_params: params.additional_params.take(),
    })
}

async fn execute_dart_tool(
    run_state: Arc<StreamRunState>,
    name: String,
    arguments_json: String,
) -> Result<String, String> {
    let call_sequence = NEXT_TOOL_CALL.fetch_add(1, Ordering::Relaxed);
    let (sender, receiver) = oneshot::channel();
    run_state.register_tool_call(call_sequence, sender)?;

    emit_stream_event(
        &run_state,
        StreamEventFields::new(STREAM_EVENT_TOOL_EXECUTE_REQUEST)
            .call_sequence(call_sequence)
            .name(Some(name.clone()))
            .arguments_json(Some(arguments_json)),
    );

    let completion = tokio::select! {
        _ = run_state.cancelled() => return Err("stream canceled".to_owned()),
        completion = receiver => completion,
    };

    match completion {
        Ok(PendingToolCompletion::Ok(result)) => Ok(result),
        Ok(PendingToolCompletion::Err(error)) => Err(error),
        Err(_) => Err(format!("tool `{name}` completion channel closed")),
    }
}

fn stored_agent<M>(name: String, agent: Arc<rig::agent::Agent<M>>) -> StoredAgent
where
    M: CompletionModel + Send + Sync + 'static,
    M::StreamingResponse: GetTokenUsage + Send + Unpin,
{
    let prompt_agent = agent.clone();
    let stream_agent = agent;

    StoredAgent {
        name,
        prompt: Box::new(move |prompt| {
            let agent = prompt_agent.clone();
            Box::pin(async move {
                let (prompt, mut history) = split_prompt_messages(prompt)?;
                if history.is_empty() {
                    agent
                        .prompt(prompt)
                        .await
                        .map_err(|error| error.to_string())
                } else {
                    agent
                        .chat(prompt, &mut history)
                        .await
                        .map_err(|error| error.to_string())
                }
            })
        }),
        stream_prompt: Box::new(move |prompt, options, run_state| {
            let agent = stream_agent.clone();
            Box::pin(async move {
                CURRENT_STREAM_RUN
                    .scope(run_state.clone(), async move {
                        let (prompt, history) = split_prompt_messages(prompt)?;
                        let mut request = if history.is_empty() {
                            agent.stream_prompt(prompt)
                        } else {
                            agent.stream_chat(prompt, history)
                        };
                        if options.max_turns >= 0 {
                            request = request.multi_turn(options.max_turns as usize);
                        }

                        let mut stream = tokio::select! {
                            _ = run_state.cancelled() => return Err("stream canceled".to_owned()),
                            stream = request => stream,
                        };
                        let mut output = String::new();

                        loop {
                            let item = tokio::select! {
                                _ = run_state.cancelled() => return Err("stream canceled".to_owned()),
                                item = stream.next() => item,
                            };
                            let Some(item) = item else {
                                break;
                            };
                        match item.map_err(|error| error.to_string())? {
                            MultiTurnStreamItem::StreamAssistantItem(item) => match item {
                                StreamedAssistantContent::Text(text) => {
                                    output.push_str(&text.text);
                                    emit_stream_event(
                                        &run_state,
                                        StreamEventFields::new(STREAM_EVENT_TEXT).text(text.text),
                                    );
                                }
                                StreamedAssistantContent::Reasoning(reasoning) => {
                                    let id = reasoning.id;
                                    for content in reasoning.content {
                                        let (kind, text) = reasoning_content_fields(content);
                                        emit_stream_event(
                                            &run_state,
                                            StreamEventFields::new(STREAM_EVENT_REASONING)
                                                .id(id.clone())
                                                .name(Some(kind))
                                                .text(text),
                                        );
                                    }
                                }
                                StreamedAssistantContent::ReasoningDelta { id, reasoning } => {
                                    emit_stream_event(
                                        &run_state,
                                        StreamEventFields::new(STREAM_EVENT_REASONING)
                                            .id(id)
                                            .text(reasoning),
                                    );
                                }
                                StreamedAssistantContent::ToolCall {
                                    tool_call,
                                    internal_call_id,
                                } => {
                                    emit_stream_event(
                                        &run_state,
                                        StreamEventFields::new(STREAM_EVENT_TOOL_CALL)
                                            .id(Some(tool_call.id))
                                            .internal_call_id(Some(internal_call_id))
                                            .name(Some(tool_call.function.name))
                                            .arguments_json(Some(
                                                tool_call.function.arguments.to_string(),
                                            )),
                                    );
                                }
                                StreamedAssistantContent::ToolCallDelta {
                                    id,
                                    internal_call_id,
                                    content,
                                } => {
                                    let fields =
                                        StreamEventFields::new(STREAM_EVENT_TOOL_CALL_DELTA)
                                            .id(Some(id))
                                            .internal_call_id(Some(internal_call_id));
                                    let fields = match content {
                                        rig::streaming::ToolCallDeltaContent::Name(name) => {
                                            fields.name(Some(name))
                                        }
                                        rig::streaming::ToolCallDeltaContent::Delta(delta) => {
                                            fields.text(delta)
                                        }
                                    };
                                    emit_stream_event(&run_state, fields);
                                }
                                StreamedAssistantContent::Final(_) => {}
                            },
                            MultiTurnStreamItem::StreamUserItem(
                                StreamedUserContent::ToolResult {
                                    tool_result,
                                    internal_call_id,
                                },
                            ) => {
                                let result_json = serde_json::to_string(&tool_result)
                                    .unwrap_or_else(|_| "{}".to_owned());
                                emit_stream_event(
                                    &run_state,
                                    StreamEventFields::new(STREAM_EVENT_TOOL_RESULT)
                                        .internal_call_id(Some(internal_call_id))
                                        .text(result_json),
                                );
                            }
                            MultiTurnStreamItem::FinalResponse(final_response) => {
                                output = final_response.response().to_owned();
                                let usage_json = serde_json::to_string(&final_response.usage())
                                    .unwrap_or_else(|_| "{}".to_owned());
                                emit_stream_event(
                                    &run_state,
                                    StreamEventFields::new(STREAM_EVENT_FINAL)
                                        .text(output.clone())
                                        .usage_json(Some(usage_json)),
                                );
                            }
                            _ => {}
                        }
                    }

                        Ok(output)
                    })
                    .await
            })
        }),
    }
}

struct StreamEventFields {
    kind: i32,
    call_sequence: i64,
    text: Option<String>,
    id: Option<String>,
    internal_call_id: Option<String>,
    name: Option<String>,
    arguments_json: Option<String>,
    usage_json: Option<String>,
}

impl StreamEventFields {
    fn new(kind: i32) -> Self {
        Self {
            kind,
            call_sequence: 0,
            text: None,
            id: None,
            internal_call_id: None,
            name: None,
            arguments_json: None,
            usage_json: None,
        }
    }

    fn text(mut self, value: impl Into<String>) -> Self {
        self.text = Some(value.into());
        self
    }

    fn id(mut self, value: Option<String>) -> Self {
        self.id = value;
        self
    }

    fn internal_call_id(mut self, value: Option<String>) -> Self {
        self.internal_call_id = value;
        self
    }

    fn name(mut self, value: Option<String>) -> Self {
        self.name = value;
        self
    }

    fn arguments_json(mut self, value: Option<String>) -> Self {
        self.arguments_json = value;
        self
    }

    fn usage_json(mut self, value: Option<String>) -> Self {
        self.usage_json = value;
        self
    }

    fn call_sequence(mut self, value: i64) -> Self {
        self.call_sequence = value;
        self
    }
}

fn reasoning_content_fields(content: ReasoningContent) -> (String, String) {
    match content {
        ReasoningContent::Text { text, .. } => ("text".to_owned(), text),
        ReasoningContent::Summary(summary) => ("summary".to_owned(), summary),
        ReasoningContent::Redacted { data } => ("redacted".to_owned(), data),
        ReasoningContent::Encrypted(data) => ("encrypted".to_owned(), data),
        _ => ("text".to_owned(), String::new()),
    }
}

#[derive(Debug)]
struct DartToolError(String);

impl fmt::Display for DartToolError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl Error for DartToolError {}

struct DartRigTool {
    definition: DartToolDefinition,
}

impl rig::tool::ToolDyn for DartRigTool {
    fn name(&self) -> String {
        self.definition.name.clone()
    }

    fn definition<'a>(
        &'a self,
        _prompt: String,
    ) -> rig::wasm_compat::WasmBoxedFuture<'a, rig::completion::ToolDefinition> {
        let definition = self.definition.clone();
        Box::pin(async move {
            rig::completion::ToolDefinition {
                name: definition.name,
                description: definition.description,
                parameters: definition.parameters,
            }
        })
    }

    fn call<'a>(
        &'a self,
        args: String,
    ) -> rig::wasm_compat::WasmBoxedFuture<'a, Result<String, rig::tool::ToolError>> {
        let name = self.definition.name.clone();
        Box::pin(async move {
            let run_state = CURRENT_STREAM_RUN.try_with(Clone::clone).map_err(|_| {
                rig::tool::ToolError::ToolCallError(Box::new(DartToolError(format!(
                    "tool `{name}` cannot run without an active Dart stream run"
                ))))
            })?;

            let call_sequence = NEXT_TOOL_CALL.fetch_add(1, Ordering::Relaxed);
            let (sender, receiver) = oneshot::channel();
            run_state
                .register_tool_call(call_sequence, sender)
                .map_err(|error| {
                    rig::tool::ToolError::ToolCallError(Box::new(DartToolError(error)))
                })?;

            emit_stream_event(
                &run_state,
                StreamEventFields::new(STREAM_EVENT_TOOL_EXECUTE_REQUEST)
                    .call_sequence(call_sequence)
                    .name(Some(name.clone()))
                    .arguments_json(Some(args)),
            );

            let completion = tokio::select! {
                _ = run_state.cancelled() => {
                    return Err(rig::tool::ToolError::ToolCallError(Box::new(
                        DartToolError("stream canceled".to_owned()),
                    )));
                }
                completion = receiver => completion,
            };

            match completion {
                Ok(PendingToolCompletion::Ok(result)) => Ok(result),
                Ok(PendingToolCompletion::Err(error)) => Err(rig::tool::ToolError::ToolCallError(
                    Box::new(DartToolError(error)),
                )),
                Err(_) => Err(rig::tool::ToolError::ToolCallError(Box::new(
                    DartToolError(format!("tool `{name}` completion channel closed")),
                ))),
            }
        })
    }
}

fn emit_stream_event(run_state: &StreamRunState, fields: StreamEventFields) {
    if run_state.is_canceled() {
        return;
    }

    let Some(callback) = run_state.callback else {
        return;
    };

    let event = Box::new(NativeRigStreamEvent {
        kind: fields.kind,
        call_sequence: fields.call_sequence,
        text: into_const_c_string(fields.text),
        id: into_const_c_string(fields.id),
        internal_call_id: into_const_c_string(fields.internal_call_id),
        name: into_const_c_string(fields.name),
        arguments_json: into_const_c_string(fields.arguments_json),
        usage_json: into_const_c_string(fields.usage_json),
    });

    unsafe { callback(run_state.user_data, Box::into_raw(event)) };
}

fn into_const_c_string(value: Option<String>) -> *const c_char {
    into_c_string(value).cast_const()
}

fn require_configured_api_key(api_key: Option<String>, provider: &str) -> Result<String, String> {
    api_key.ok_or_else(|| format!("{provider} apiKey must be passed in RigAgentConfig"))
}

fn read_required_string(value: *const c_char, name: &str) -> Result<String, String> {
    read_optional_string(value).ok_or_else(|| format!("{name} is required"))
}

fn read_optional_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }

    let value = unsafe { CStr::from_ptr(value) }
        .to_string_lossy()
        .into_owned();
    if value.is_empty() { None } else { Some(value) }
}

fn handle_error(error: impl Into<String>) -> NativeRigHandleResult {
    NativeRigHandleResult {
        handle: 0,
        name: ptr::null_mut(),
        error: into_c_string(Some(error.into())),
    }
}

fn prompt_error(error: impl Into<String>) -> NativeRigPromptResult {
    NativeRigPromptResult {
        output: ptr::null_mut(),
        error: into_c_string(Some(error.into())),
    }
}

fn bytes_result(bytes: Vec<u8>) -> *mut NativeRigBytesResult {
    if bytes.is_empty() {
        return Box::into_raw(Box::new(NativeRigBytesResult {
            data: ptr::null_mut(),
            data_len: 0,
            error: ptr::null_mut(),
        }));
    }

    let mut bytes = bytes.into_boxed_slice();
    let data_len = bytes.len() as isize;
    let data = bytes.as_mut_ptr();
    mem::forget(bytes);

    Box::into_raw(Box::new(NativeRigBytesResult {
        data,
        data_len,
        error: ptr::null_mut(),
    }))
}

fn bytes_error(error: impl Into<String>) -> NativeRigBytesResult {
    NativeRigBytesResult {
        data: ptr::null_mut(),
        data_len: 0,
        error: into_c_string(Some(error.into())),
    }
}

fn into_c_string(value: Option<String>) -> *mut c_char {
    match value {
        Some(value) => CString::new(value)
            .unwrap_or_else(|_| CString::new("native string contained NUL").unwrap())
            .into_raw(),
        None => ptr::null_mut(),
    }
}

fn free_string(value: *mut c_char) {
    if !value.is_null() {
        let _ = unsafe { CString::from_raw(value) };
    }
}

fn free_const_string(value: *const c_char) {
    free_string(value.cast_mut());
}

#[cfg(test)]
mod tests {
    use super::*;

    fn settings_with_default_max_turns(default_max_turns: Option<usize>) -> AgentSettings {
        AgentSettings {
            temperature: None,
            max_tokens: None,
            default_max_turns,
            output_schema: None,
            additional_params: None,
            tools: Vec::new(),
        }
    }

    #[test]
    fn stream_max_turns_prefers_explicit_options() {
        let settings = settings_with_default_max_turns(Some(8));

        assert_eq!(
            resolve_stream_max_turns(NativeRigStreamOptions { max_turns: 0 }, &settings),
            0
        );
        assert_eq!(
            resolve_stream_max_turns(NativeRigStreamOptions { max_turns: 3 }, &settings),
            3
        );
    }

    #[test]
    fn stream_max_turns_uses_config_default_then_fallback() {
        assert_eq!(
            resolve_stream_max_turns(
                NativeRigStreamOptions { max_turns: -1 },
                &settings_with_default_max_turns(Some(4)),
            ),
            4
        );
        assert_eq!(
            resolve_stream_max_turns(
                NativeRigStreamOptions { max_turns: -1 },
                &settings_with_default_max_turns(None),
            ),
            8
        );
    }

    #[test]
    fn gemini_model_turn_budget_matches_rig_core_tool_turn_semantics() {
        assert_eq!(max_model_turns_for_tool_turns(0), 2);
        assert_eq!(max_model_turns_for_tool_turns(1), 3);
        assert_eq!(max_model_turns_for_tool_turns(8), 10);
    }
}
