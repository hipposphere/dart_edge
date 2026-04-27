use better_auth::{OpenApiSpec, core_paths};
use dart_edge_http_server_core::{NativeHttpMethod, NativeHttpRoute};

pub fn list_routes(spec: &OpenApiSpec, base_path: &str) -> Vec<NativeHttpRoute> {
    let mut routes = listed_routes_from_openapi(spec, base_path);
    append_native_core_route_overrides(&mut routes, base_path);
    routes.sort_by(|left, right| {
        left.path
            .cmp(&right.path)
            .then_with(|| left.method.cmp(&right.method))
    });
    routes
}

fn listed_routes_from_openapi(spec: &OpenApiSpec, base_path: &str) -> Vec<NativeHttpRoute> {
    let mut routes = Vec::new();
    for (path, operations) in &spec.paths {
        for (method_name, operation) in operations {
            let Some(method) = NativeHttpMethod::from_openapi_name(method_name) else {
                continue;
            };
            let plugin_name = operation
                .tags
                .first()
                .filter(|tag| tag.as_str() != "core")
                .cloned();
            routes.push(NativeHttpRoute::new(
                method,
                join_path(base_path, path),
                &operation.operation_id,
                accepts_json_body(method),
                plugin_name,
            ));
        }
    }
    routes
}

fn append_native_core_route_overrides(routes: &mut Vec<NativeHttpRoute>, base_path: &str) {
    push_route_if_missing(
        routes,
        NativeHttpRoute::new(
            NativeHttpMethod::Get,
            join_path(base_path, core_paths::OPENAPI_SPEC),
            "openapi_spec",
            false,
            None,
        ),
    );
    push_route_if_missing(
        routes,
        NativeHttpRoute::new(
            NativeHttpMethod::Delete,
            join_path(base_path, core_paths::DELETE_USER),
            "delete_user_delete",
            true,
            None,
        ),
    );
}

fn push_route_if_missing(routes: &mut Vec<NativeHttpRoute>, route: NativeHttpRoute) {
    if routes
        .iter()
        .any(|existing| existing.method == route.method && existing.path == route.path)
    {
        return;
    }
    routes.push(route);
}

fn accepts_json_body(method: NativeHttpMethod) -> bool {
    matches!(
        method,
        NativeHttpMethod::Post
            | NativeHttpMethod::Put
            | NativeHttpMethod::Patch
            | NativeHttpMethod::Delete
    )
}

pub fn join_path(prefix: &str, path: &str) -> String {
    let prefix = normalize_base_path(prefix);
    let path = normalize_relative_path(path);

    if prefix == "/" {
        return path;
    }
    if path == "/" {
        return prefix;
    }

    format!("{prefix}{path}")
}

pub fn normalize_base_path(value: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() || trimmed == "/" {
        return "/".to_string();
    }

    let without_trailing = trimmed.trim_end_matches('/');
    if without_trailing.starts_with('/') {
        without_trailing.to_string()
    } else {
        format!("/{without_trailing}")
    }
}

fn normalize_relative_path(value: &str) -> String {
    if value.is_empty() || value == "/" {
        return "/".to_string();
    }

    if value.starts_with('/') {
        value.to_string()
    } else {
        format!("/{value}")
    }
}
