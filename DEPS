vars = {
  "sdk_version": "latest",
}

deps = {
}

deps_os = {
  "win": {
    "src/third_party/cygwin":
      "http://src.chromium.org/svn/trunk/deps/third_party/cygwin@11984",
  },
}

hooks = [
  {
    "pattern": ".",
    "action": ["python", "src/build_tools/download_sdk.py",
               "-v", Var("sdk_version")],
  }
]
