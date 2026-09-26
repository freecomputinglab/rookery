import { defineConfig } from "vite";

// One IIFE bundle only: `entrypoint` and `css_stylesheet` in `typst.toml`
// point straight at `src/`, so `dist/` holds nothing but the JS bundle a
// release ships. `dist/` is gitignored — it is a build artifact, and the
// release workflow tars it alongside `src/`.
export default defineConfig({
  build: {
    lib: {
      entry: "src/todos.js",
      formats: ["iife"],
      name: "RookeryTodos",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
