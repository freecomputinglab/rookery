import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/pinboard.js",
      formats: ["iife"],
      name: "RookeryPinboard",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
