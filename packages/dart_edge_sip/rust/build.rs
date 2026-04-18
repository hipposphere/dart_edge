use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=native/pjsip_bridge.c");
    println!("cargo:rerun-if-changed=native/pjsip_bridge.h");

    let pjproject = pkg_config::Config::new()
        .cargo_metadata(false)
        .statik(true)
        .probe("libpjproject")
        .expect(
            "dart_edge_sip requires pjproject via pkg-config. Install pjproject \
             and ensure `pkg-config --cflags --libs libpjproject` succeeds.",
        );
    let openssl = pkg_config::Config::new()
        .cargo_metadata(false)
        .probe("openssl")
        .expect(
            "dart_edge_sip requires OpenSSL development libraries. Ensure \
             `pkg-config --libs openssl` succeeds.",
        );

    emit_links(&pjproject);
    emit_links(&openssl);
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

fn emit_links(library: &pkg_config::Library) {
    for link_path in &library.link_paths {
        println!("cargo:rustc-link-search=native={}", link_path.display());
    }
    for framework_path in &library.framework_paths {
        println!(
            "cargo:rustc-link-search=framework={}",
            framework_path.display()
        );
    }
    for lib in &library.libs {
        println!("cargo:rustc-link-lib={lib}");
    }
    for framework in &library.frameworks {
        println!("cargo:rustc-link-lib=framework={framework}");
    }
}
