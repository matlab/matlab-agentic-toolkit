# Wizard / Stepper Layout

**Primary user task:** Complete a guided, sequential workflow — each step feeds the next and must be completed in order.

```
┌────────────────────────────────────────────────────────┐
│  ①──────────②──────────③──────────④                   │  ← step indicator (fixed ~64px)
│  Load Data   Configure   Preview    Export             │
├────────────────────────────────────────────────────────┤
│                                                        │
│   Step content                                         │  ← content area (fills space)
│   (one step visible at a time)                         │
│                                                        │
│                                                        │
├────────────────────────────────────────────────────────┤
│                              [ Back ]  [ Next / Finish]│  ← nav row (fixed ~52px)
└────────────────────────────────────────────────────────┘
```

**When to choose:** The task has a clear beginning and end, with decisions at each step that constrain what comes next. Examples: data import wizard, model training setup, report configuration, export workflow.

**Key rules:**
- Steps must be completable in order — don't let the user skip to step 3 without completing step 2
- The step indicator shows overall progress; it is not a navigation control (distinguish from tabs)
- "Back" revisits the previous step — preserve entered values when going back
- The final step's "Next" button becomes "Finish" (or "Export", "Run", etc.)
- Keep each step focused: one decision, one configuration, one confirmation

---

## UIFigure app — uigridlayout Skeleton

```matlab
fig = uifigure('Name', 'Wizard', 'Position', [200 150 700 500]);

rootGrid = uigridlayout(fig, [3 1]);
rootGrid.RowHeight  = {64, '1x', 52};
rootGrid.Padding    = [0 0 0 0];
rootGrid.RowSpacing = 0;

% ── Step indicator ───────────────────────────────────────
stepPanel = uipanel(rootGrid);
stepPanel.Layout.Row = 1;
stepPanel.BorderType = 'none';
stepGrid = uigridlayout(stepPanel, [1 1]);  % draw step labels dynamically

% ── Content area ─────────────────────────────────────────
contentPanel = uipanel(rootGrid);
contentPanel.Layout.Row = 2;
contentPanel.BorderType = 'none';

% Build one grid per step; toggle Visible to switch steps
step1Grid = uigridlayout(contentPanel, [4 2]);
step1Grid.Padding = [24 24 24 24];
% ... add step 1 controls

step2Grid = uigridlayout(contentPanel, [3 1]);
step2Grid.Padding   = [24 24 24 24];
step2Grid.Visible   = 'off';
% ... add step 2 controls

step3Grid = uigridlayout(contentPanel, [1 1]);
step3Grid.Padding   = [24 24 24 24];
step3Grid.Visible   = 'off';
% ... step 3: preview or confirmation

% ── Navigation row ───────────────────────────────────────
navPanel = uipanel(rootGrid);
navPanel.Layout.Row = 3;
navPanel.BorderType = 'none';
navGrid = uigridlayout(navPanel, [1 3]);
navGrid.ColumnWidth = {'1x', 'fit', 'fit'};
navGrid.Padding     = [8 8 8 8];
navGrid.ColumnSpacing = 8;

btnBack = uibutton(navGrid, 'Text', 'Back');
btnBack.Layout.Column = 2;
btnBack.Enable = 'off';  % disabled on step 1
btnNext = uibutton(navGrid, 'Text', 'Next');
btnNext.Layout.Column = 3;
```

### Step progression logic

```matlab
% State
currentStep = 1;
totalSteps  = 3;
steps       = {step1Grid, step2Grid, step3Grid};

function showStep(n)
    for i = 1:totalSteps
        steps{i}.Visible = 'off';
    end
    steps{n}.Visible = 'on';
    btnBack.Enable = matlab.lang.OnOffSwitchState(n > 1);
    if n == totalSteps
        btnNext.Text = 'Finish';
    else
        btnNext.Text = 'Next';
    end
    currentStep = n;
    updateStepIndicator(n);
end

btnBack.ButtonPushedFcn = @(~,~) showStep(currentStep - 1);
btnNext.ButtonPushedFcn = @(~,~) handleNext();

function handleNext()
    if currentStep < totalSteps
        if validateStep(currentStep)
            showStep(currentStep + 1);
        end
    else
        finishWizard();
    end
end
```

### Drawing the step indicator

```matlab
function updateStepIndicator(activeStep)
    delete(stepGrid.Children);  % clear and redraw
    n = totalSteps;
    cols = {};
    for i = 1:n
        cols{end+1} = 'fit';          % step circle
        if i < n; cols{end+1} = '1x'; end  % connector
    end
    stepGrid.ColumnWidth = cols;

    for i = 1:n
        col = (i - 1) * 2 + 1;
        lbl = uilabel(stepGrid, 'Text', sprintf('%d  Step %d', i, i), ...
            'HorizontalAlignment', 'center');
        lbl.Layout.Column = col;
        if i == activeStep
            lbl.FontWeight = 'bold';
        elseif i < activeStep
            lbl.FontColor = [0.2 0.6 0.2];  % completed
        else
            lbl.FontColor = [0.6 0.6 0.6];  % future
        end
        if i < n
            connector = uilabel(stepGrid, 'Text', '────', 'FontColor', [0.8 0.8 0.8]);
            connector.Layout.Column = col + 1;
        end
    end
end
```

---

## UIHTML/web app — CSS + JS Skeleton

```html
<div class="wizard">
    <header class="step-indicator">
        <div class="step done">
            <div class="step-number">✓</div>
            <span class="step-label">Load Data</span>
        </div>
        <div class="step-connector"></div>
        <div class="step active">
            <div class="step-number">2</div>
            <span class="step-label">Configure</span>
        </div>
        <div class="step-connector"></div>
        <div class="step">
            <div class="step-number">3</div>
            <span class="step-label">Preview</span>
        </div>
    </header>

    <main class="step-content">
        <section class="step-panel" id="step-1"><!-- step 1 content --></section>
        <section class="step-panel active" id="step-2"><!-- step 2 content --></section>
        <section class="step-panel" id="step-3"><!-- step 3 content --></section>
    </main>

    <footer class="nav-row">
        <button id="btn-back" disabled>Back</button>
        <button id="btn-next">Next</button>
    </footer>
</div>
```

```css
.wizard {
    display: grid;
    grid-template-rows: 72px 1fr 60px;
    height: 100vh;
}

.step-indicator {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    padding: 0 var(--space-8);
    border-bottom: 1px solid var(--border);
}

.step { display: flex; align-items: center; gap: var(--space-2); }

.step-number {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: var(--text-sm);
    font-weight: var(--fw-semi);
    background: var(--bg-secondary);
    color: var(--text-secondary);
    flex-shrink: 0;
}
.step.active .step-number { background: var(--accent); color: white; }
.step.done   .step-number { background: var(--success); color: white; }

.step-label { font-size: var(--text-sm); color: var(--text-secondary); white-space: nowrap; }
.step.active .step-label { color: var(--text-primary); font-weight: var(--fw-semi); }

.step-connector { flex: 1; height: 2px; background: var(--border); min-width: 24px; max-width: 80px; }
.step.done + .step-connector { background: var(--success); }

.step-content { overflow-y: auto; padding: var(--space-6); }

.step-panel { display: none; }
.step-panel.active { display: block; }

.nav-row {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-3);
    padding: var(--space-4);
    border-top: 1px solid var(--border);
}
```

```javascript
let currentStep = 1;
const totalSteps = 3;

function goToStep(n) {
    document.querySelectorAll('.step-panel').forEach((p, i) => {
        p.classList.toggle('active', i + 1 === n);
    });
    document.getElementById('btn-back').disabled = n === 1;
    document.getElementById('btn-next').textContent = n === totalSteps ? 'Finish' : 'Next';
    updateIndicator(n);
    currentStep = n;
}

document.getElementById('btn-back').addEventListener('click', () => goToStep(currentStep - 1));
document.getElementById('btn-next').addEventListener('click', () => {
    if (currentStep < totalSteps && validateStep(currentStep)) {
        goToStep(currentStep + 1);
    } else if (currentStep === totalSteps) {
        finish();
    }
});
```

---

## Common Variations

| Variation | Change |
|---|---|
| Progress bar instead of step circles | Replace indicator with `<progress>` element or a `div` with `width: N%` |
| Step labels below circles | Flex-column on `.step`, center align |
| Allow reviewing completed steps | Enable clicking done step numbers; `done` steps can be revisited |
| Non-linear branching | Keep as wizard but show/hide steps based on previous answers |

---

## Composition

- **UIFigure app:** `references/uifigure/mvvm-guide.md` to hold wizard state (current step, collected values, validation); use `arguments` blocks in step validation functions
- **UIHTML/web app:** `references/uihtml/mvvm-guide.md` for the wizard ViewModel (holds step data, validation state, transitions); `references/uihtml/styling-guide.md` for form control and button styling

----

Copyright 2026 The MathWorks, Inc.

----
