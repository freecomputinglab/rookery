import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/search.js",
      formats: ["iife"],
      name: "RookerySearch",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
