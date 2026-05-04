use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=native/pjsip_bridge.c");
    println!("cargo:rerun-if-changed=native/pjsip_bridge.h");

    let pjproject = pkg_config::Config::new()
        .cargo_metadata(false)
        .probe("libpjproject")
        .expect(
            "dart_edge_sip requires pjproject via pkg-config. Install pjproject \
             and ensure `pkg-config --cflags --libs libpjproject` succeeds.",
        );
    emit_late_pjproject_lookup_args();

    let mut build = cc::Build::new();
    build.file("native/pjsip_bridge.c");
    build.include("native");
    build.flag_if_supported("-std=c11");

    for include_path in &pjproject.include_paths {
        build.include(include_path);
    }
    for (name, value) in &pjproject.defines {
        build.define(name, value.as_deref());
    }

    if let Some(target) = env::var_os("TARGET") {
        let target = PathBuf::from(target);
        if target.to_string_lossy().contains("apple") {
            build.flag_if_supported("-Wno-deprecated-declarations");
        }
    }

    build.compile("dart_edge_sip_pjsip_bridge");
}

fn emit_late_pjproject_lookup_args() {
    let target = env::var("TARGET").unwrap_or_default();
    if target.contains("apple") {
        println!("cargo:rustc-link-arg-cdylib=-Wl,-undefined,dynamic_lookup");
    } else if target.contains("linux") {
        println!("cargo:rustc-link-arg-cdylib=-Wl,--allow-shlib-undefined");
    }
}
