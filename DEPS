vars = {
  "compiler_version": "2270",
}

deps = {
}

hooks = [
  {
    "pattern": ".",
    "action": ["python", "src/build_tools/download_compilers.py",
               "-v", Var("compiler_version")],
  }
]

