use std::collections::HashMap;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NativeBytes {
    pub ptr: *const u8,
    pub len: isize,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NativeOwnedBytes {
    pub ptr: *mut u8,
    pub len: isize,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NativePair {
    pub key: NativeBytes,
    pub value: NativeBytes,
}

pub struct OwnedBytes {
    bytes: Box<[u8]>,
}

pub struct OwnedPair {
    key: OwnedBytes,
    value: OwnedBytes,
}

impl NativeBytes {
    pub const fn empty() -> Self {
        Self {
            ptr: std::ptr::null(),
            len: 0,
        }
    }
}

impl OwnedBytes {
    pub fn from_vec(bytes: Vec<u8>) -> Self {
        Self {
            bytes: bytes.into_boxed_slice(),
        }
    }

    pub fn from_string(value: String) -> Self {
        Self::from_vec(value.into_bytes())
    }

    pub fn as_native(&self) -> NativeBytes {
        NativeBytes {
            ptr: self.bytes.as_ptr(),
            len: self.bytes.len() as isize,
        }
    }
}

impl OwnedPair {
    pub fn new(key: String, value: String) -> Self {
        Self {
            key: OwnedBytes::from_string(key),
            value: OwnedBytes::from_string(value),
        }
    }

    pub fn as_native(&self) -> NativePair {
        NativePair {
            key: self.key.as_native(),
            value: self.value.as_native(),
        }
    }
}

pub fn owned_pairs_from_map(values: HashMap<String, String>) -> Vec<OwnedPair> {
    values
        .into_iter()
        .map(|(key, value)| OwnedPair::new(key, value))
        .collect()
}

pub fn native_pairs_from_owned(values: &[OwnedPair]) -> Box<[NativePair]> {
    values
        .iter()
        .map(OwnedPair::as_native)
        .collect::<Vec<_>>()
        .into_boxed_slice()
}

pub fn boxed_pairs_ptr(values: &[NativePair]) -> *const NativePair {
    if values.is_empty() {
        std::ptr::null()
    } else {
        values.as_ptr()
    }
}

/// # Safety
///
/// `value.ptr` must either be null with `len == 0` or point to a valid UTF-8
/// byte sequence of length `len`.
pub unsafe fn read_native_string(value: NativeBytes) -> Option<String> {
    if value.ptr.is_null() || value.len <= 0 {
        return Some(String::new());
    }

    let slice = unsafe { std::slice::from_raw_parts(value.ptr, value.len as usize) };
    std::str::from_utf8(slice).ok().map(ToOwned::to_owned)
}

/// # Safety
///
/// `values` must either be null with `count <= 0` or point to `count`
/// consecutive `NativePair` values whose embedded byte pointers follow the
/// requirements of [`read_native_string`].
pub unsafe fn read_pairs_vec(values: *const NativePair, count: isize) -> Vec<(String, String)> {
    if count <= 0 || values.is_null() {
        return Vec::new();
    }

    let mut result = Vec::with_capacity(count as usize);
    for index in 0..count {
        let pair = unsafe { values.offset(index).read() };
        let Some(key) = (unsafe { read_native_string(pair.key) }) else {
            continue;
        };
        let Some(value) = (unsafe { read_native_string(pair.value) }) else {
            continue;
        };
        result.push((key, value));
    }
    result
}

/// # Safety
///
/// Same requirements as [`read_pairs_vec`].
pub unsafe fn read_pairs_map(values: *const NativePair, count: isize) -> HashMap<String, String> {
    let mut result = HashMap::with_capacity(count.max(0) as usize);
    for (key, value) in unsafe { read_pairs_vec(values, count) } {
        result.insert(key, value);
    }
    result
}

pub fn into_native_owned_bytes(bytes: Vec<u8>) -> NativeOwnedBytes {
    let mut boxed_bytes = bytes.into_boxed_slice();
    let native_bytes = NativeOwnedBytes {
        ptr: boxed_bytes.as_mut_ptr(),
        len: boxed_bytes.len() as isize,
    };
    std::mem::forget(boxed_bytes);
    native_bytes
}

/// # Safety
///
/// `value` must come from [`into_native_owned_bytes`] or an equivalent
/// allocation using a boxed byte slice with the same pointer and length.
pub unsafe fn free_owned_bytes(value: NativeOwnedBytes) {
    if value.ptr.is_null() {
        return;
    }

    let slice = std::ptr::slice_from_raw_parts_mut(value.ptr, value.len as usize);
    unsafe {
        let _ = Box::<[u8]>::from_raw(slice);
    }
}
