# Notes for Upstream PRs

This fork adds Vulkan support for Intel Arc GPUs on Windows. Two upstream PRs are needed.

## PR 1 — ggml-org/whisper.cpp
Add Vulkan server binaries to official whisper.cpp releases.
- Add Windows Vulkan build to release CI (companion DLLs: ggml-vulkan.dll, ggml.dll, ggml-base.dll, ggml-cpu.dll, whisper.dll)
- Zip as `whisper-vulkan-bin-x64.zip`
- Reference issue: https://github.com/ggml-org/ggml/issues/... (Intel Arc flash-attn bug)

## PR 2 — OpenWhispr/openwhispr
Integrate Vulkan binary + GPU detection.

**Files to change:**
- `scripts/download-whisper-cpp.js`: remove `WHISPER_VULKAN_REPO`, move `win32-x64-vulkan` into `BINARIES` pointing to the official `WHISPER_CPP_REPO`
- `src/utils/vulkanDetection.js`: already exists in fork — submit as-is or reuse existing detection logic
- `src/helpers/whisperServer.js`: Vulkan binary selection in `getServerBinaryPath()` + `--no-flash-attn` flag in `_doStart()`
- `src/helpers/whisper.js`: `detectVulkanGpu()` warmup in `initializeAtStartup()`
- `src/updater.js` + `electron-builder.json`: revert `owner` back to `"OpenWhispr"`
- Delete `.github/workflows/sync-upstream.yml` (fork-only infra)
- Delete `PR_NOTES.md` and `scripts/apply-vulkan-patch.ps1`
