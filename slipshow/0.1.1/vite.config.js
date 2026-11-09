import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/slipshow.js",
      formats: ["iife"],
      name: "RookerySlipshow",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
