vars = {
  "sdk_version": "latest",
}

deps = {
}

hooks = [
  {
    "pattern": ".",
    "action": ["python", "src/build_tools/download_sdk.py",
               "-v", Var("sdk_version")],
  }
]

