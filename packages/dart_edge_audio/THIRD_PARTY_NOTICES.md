# Third-party notices

The prebuilt native assets for `dart_edge_audio` include third-party software.

## FFmpeg

M4A/AAC-LC and FLAC output use FFmpeg 9.0 through `ffmpeg-next` and
`ffmpeg-sys-next`. The native build enables the FFmpeg libraries required for
codec and container access and does not enable the Cargo features for GPL or
nonfree components.

FFmpeg is licensed under the GNU Lesser General Public License version 2.1 or
later unless optional components change that license. License text, source,
and build information are available from:

- https://ffmpeg.org/legal.html
- https://github.com/FFmpeg/FFmpeg/tree/release/9.0
- https://github.com/zmwangx/rust-ffmpeg
- https://github.com/zmwangx/rust-ffmpeg-sys
