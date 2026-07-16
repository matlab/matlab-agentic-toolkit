# Python-to-MATLAB Conversion Rules

| Python | MATLAB |
|--------|--------|
| `import module` | `py.module.function()` or `py.importlib.import_module('module.submodule')` |
| `from module import Class` | `Class = py.module.Class` or via `py.importlib.import_module()` |
| `model = Model()` | `model = py.module.Model()` |
| `model.eval()` | `model.eval()` |
| `model.to("cuda")` | `model.to("cuda")` |
| `torch.no_grad()` / `torch.inference_mode()` | `py.torch.set_grad_enabled(false)` before, `py.torch.set_grad_enabled(true)` after |
| `torch.tensor(x)` | `py.torch.tensor(x)` |
| `result.numpy()` | `double(result.numpy())` or `single(result.numpy())` |
| `result.cpu().detach().numpy()` | `double(result.cpu().detach().numpy())` |
| `result.sigmoid()` | `result.sigmoid()` |
| `dict["key"]` | `struct(result)` then access fields, or `result{"key"}` |
| `with torch.inference_mode():` | `py.torch.set_grad_enabled(false)` before, `py.torch.set_grad_enabled(true)` after |
| `with` statement (context managers) | NEVER use `__enter__`/`__exit__` — double underscores are invalid MATLAB syntax. Find an equivalent non-context-manager API instead. |
| `torch.hub.load('org/repo', 'model')` | `py.torch.hub.load('org/repo', 'model')` |
| `Model.from_pretrained("name")` | `py.module.Model.from_pretrained("name")` |
| `PIL.Image.open("img.jpg")` / `cv2.imread(...)` | `imread("img.jpg")` — always use MATLAB's `imread` for loading images, never Python image libraries |

----

Copyright 2026 The MathWorks, Inc.

----
