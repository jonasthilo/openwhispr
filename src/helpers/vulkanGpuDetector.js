const { exec, execSync } = require("child_process");
const debugLogger = require("./debugLogger");

const VULKAN_GPU_PATTERNS = [
  /intel.+arc/i,        // Intel Arc (discrete and integrated)
  /amd\s+radeon\s+rx/i, // AMD Radeon RX discrete GPUs
];

const PS_CMD =
  "powershell -NoProfile -Command \"Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name\"";

let cachedResult = null;

function parseOutput(stdout) {
  const names = stdout.trim().split("\n").map((s) => s.trim()).filter(Boolean);
  const vulkanGpus = names.filter((n) => VULKAN_GPU_PATTERNS.some((p) => p.test(n)));
  return vulkanGpus.length > 0
    ? { hasVulkanGpu: true, gpuName: vulkanGpus[0], gpus: vulkanGpus }
    : { hasVulkanGpu: false };
}

async function detectVulkanGpu() {
  if (process.platform !== "win32") {
    return { hasVulkanGpu: false, error: `Vulkan binary not available for ${process.platform}` };
  }
  if (cachedResult !== null) return cachedResult;

  cachedResult = await new Promise((resolve) => {
    exec(PS_CMD, { timeout: 5000, windowsHide: true }, (err, stdout) => {
      if (err) {
        debugLogger.warn("[vulkanGpuDetector] Detection failed:", err.message);
        resolve({ hasVulkanGpu: false, error: err.message });
      } else {
        resolve(parseOutput(stdout));
      }
    });
  });

  debugLogger.log("[vulkanGpuDetector] Result:", cachedResult);
  return cachedResult;
}

function clearCache() {
  cachedResult = null;
  debugLogger.log("[vulkanGpuDetector] Cache cleared");
}

async function getRecommendedVariant() {
  if (process.platform !== "win32") return "cpu";
  const result = await detectVulkanGpu();
  return result.hasVulkanGpu ? "vulkan" : "cpu";
}

function getRecommendedVariantSync() {
  if (process.platform !== "win32") return "cpu";
  if (cachedResult !== null) return cachedResult.hasVulkanGpu ? "vulkan" : "cpu";

  try {
    const stdout = execSync(PS_CMD, { encoding: "utf8", timeout: 5000, windowsHide: true });
    cachedResult = parseOutput(stdout);
  } catch (err) {
    debugLogger.warn("[vulkanGpuDetector] Sync detection failed:", err.message);
    cachedResult = { hasVulkanGpu: false, error: err.message };
  }

  debugLogger.log("[vulkanGpuDetector] Sync result:", cachedResult);
  return cachedResult.hasVulkanGpu ? "vulkan" : "cpu";
}

module.exports = { detectVulkanGpu, clearCache, getRecommendedVariant, getRecommendedVariantSync };
