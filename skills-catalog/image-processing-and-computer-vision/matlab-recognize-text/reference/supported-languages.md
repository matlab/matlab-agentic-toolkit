# Supported OCR Languages

The `ocr` function supports 64+ languages via the OCR Language Data support package add-on.

## Usage

```matlab
% Specify language model
results = ocr(I, Model="french");

% Fast variant (quantized, less accurate but faster)
results = ocr(I, Model="french-fast");
```

## Available Languages

| Language | Model Name |
|----------|-----------|
| Afrikaans | `"afrikaans"` |
| Albanian | `"albanian"` |
| Ancient Greek | `"ancientgreek"` |
| Arabic | `"arabic"` |
| Azerbaijani | `"azerbaijani"` |
| Basque | `"basque"` |
| Belarusian | `"belarusian"` |
| Bengali | `"bengali"` |
| Bulgarian | `"bulgarian"` |
| Catalan | `"catalan"` |
| Cherokee | `"cherokee"` |
| Chinese (Simplified) | `"chinesesimplified"` |
| Chinese (Traditional) | `"chinesetraditional"` |
| Croatian | `"croatian"` |
| Czech | `"czech"` |
| Danish | `"danish"` |
| Dutch | `"dutch"` |
| English | `"english"` |
| Esperanto | `"esperanto"` |
| Esperanto (Alternative) | `"esperantoalternative"` |
| Estonian | `"estonian"` |
| Finnish | `"finnish"` |
| Frankish | `"frankish"` |
| French | `"french"` |
| Galician | `"galician"` |
| German | `"german"` |
| Greek | `"greek"` |
| Hebrew | `"hebrew"` |
| Hindi | `"hindi"` |
| Hungarian | `"hungarian"` |
| Icelandic | `"icelandic"` |
| Indonesian | `"indonesian"` |
| Italian | `"italian"` |
| Italian (Old) | `"italianold"` |
| Japanese | `"japanese"` |
| Kannada | `"kannada"` |
| Korean | `"korean"` |
| Latvian | `"latvian"` |
| Lithuanian | `"lithuanian"` |
| Macedonian | `"macedonian"` |
| Malay | `"malay"` |
| Malayalam | `"malayalam"` |
| Maltese | `"maltese"` |
| Math Equation | `"mathequation"` |
| Middle English | `"middleenglish"` |
| Middle French | `"middlefrench"` |
| Norwegian | `"norwegian"` |
| Polish | `"polish"` |
| Portuguese | `"portuguese"` |
| Romanian | `"romanian"` |
| Russian | `"russian"` |
| Serbian (Latin) | `"serbianlatin"` |
| Slovakian | `"slovakian"` |
| Slovenian | `"slovenian"` |
| Spanish | `"spanish"` |
| Spanish (Old) | `"spanishold"` |
| Swahili | `"swahili"` |
| Swedish | `"swedish"` |
| Tagalog | `"tagalog"` |
| Tamil | `"tamil"` |
| Telugu | `"telugu"` |
| Thai | `"thai"` |
| Turkish | `"turkish"` |
| Ukrainian | `"ukrainian"` |

## Special Models

| Model | Use Case |
|-------|----------|
| `"english"` | Default; general English text |
| `"seven-segment"` | Seven-segment LED/LCD displays |
| `"mathequation"` | Mathematical equations and symbols |
| `"<language>-fast"` | Quantized variant of any language (faster, slightly less accurate) |

## Installation

The OCR Language Data support package must be installed for non-English languages:

```matlab
% Check if support package is installed
supportPackageInstalled = ~isempty(which("ocr")) && ...
    exist(fullfile(matlabroot,"toolbox","vision","supportpackages","ocrlanguagedata"), "dir");
```

Install via Add-On Explorer or MATLAB command line if not present.


----
Copyright 2026 The MathWorks, Inc.
----
