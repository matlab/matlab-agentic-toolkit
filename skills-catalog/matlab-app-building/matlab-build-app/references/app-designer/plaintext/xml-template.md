# XML Configuration Template

**Always use GridLayout for layout.** Do not use pixel-based `<Position>` for component placement. Set `<AutoResizeChildren>'off'</AutoResizeChildren>` on the UIFigure and use nested GridLayouts to build responsive layouts.

## Minimal App (UIFigure only)

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<MATLABApp schemaVersion='1.0.0' release='R2026b.0' minRelease='R2026b'>
    <UIFigure name='UIFigure'>
        <Name>'MATLAB App'</Name>
        <Position>[100 100 640 480]</Position>
    </UIFigure>
    <AppDetails>
        <Name>MyApp</Name>
        <Version>1.0</Version>
    </AppDetails>
    <InternalData>
        <AppId>GENERATE-A-UUID-HERE</AppId>
    </InternalData>
    <!-- Thumbnail is used by file previewers. To change how the thumbnail is captured or stored, use the App Details dialog box in App Designer. -->
    <Thumbnail autoCapture='true'></Thumbnail>
</MATLABApp>
```

## App with Form Layout (Grid-based)

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<MATLABApp schemaVersion='1.0.0' release='R2026b.0' minRelease='R2026b'>
    <UIFigure name='UIFigure'>
        <AutoResizeChildren>'off'</AutoResizeChildren>
        <Name>'My App Title'</Name>
        <Position>[100 100 640 480]</Position>
        <Children>
            <GridLayout name='MainGrid'>
                <ColumnWidth>{'1x'}</ColumnWidth>
                <Padding>[10 10 10 10]</Padding>
                <RowHeight>{'fit', 'fit', '1x'}</RowHeight>
                <RowSpacing>10</RowSpacing>
                <Children>
                    <Label name='TitleLabel'>
                        <FontSize>18</FontSize>
                        <FontWeight>'bold'</FontWeight>
                        <Layout>
                            <Column>1</Column>
                            <Row>1</Row>
                        </Layout>
                        <Text>'Welcome'</Text>
                    </Label>
                    <GridLayout name='InputGrid'>
                        <ColumnSpacing>6</ColumnSpacing>
                        <ColumnWidth>{'fit', '1x', 'fit'}</ColumnWidth>
                        <Layout>
                            <Column>1</Column>
                            <Row>2</Row>
                        </Layout>
                        <Padding>[0 0 0 0]</Padding>
                        <RowHeight>{'fit'}</RowHeight>
                        <Children>
                            <Label name='InputEditFieldLabel'>
                                <HorizontalAlignment>'right'</HorizontalAlignment>
                                <Layout>
                                    <Column>1</Column>
                                    <Row>1</Row>
                                </Layout>
                                <Text>'Input:'</Text>
                            </Label>
                            <EditField name='InputEditField' label='InputEditFieldLabel'>
                                <Layout>
                                    <Column>2</Column>
                                    <Row>1</Row>
                                </Layout>
                                <ValueChangedFcn>InputEditFieldValueChanged</ValueChangedFcn>
                            </EditField>
                            <Button name='GoButton'>
                                <ButtonPushedFcn>GoButtonPushed</ButtonPushedFcn>
                                <Layout>
                                    <Column>3</Column>
                                    <Row>1</Row>
                                </Layout>
                                <Text>'Go'</Text>
                            </Button>
                        </Children>
                    </GridLayout>
                    <TextArea name='OutputTextArea'>
                        <Layout>
                            <Column>1</Column>
                            <Row>3</Row>
                        </Layout>
                    </TextArea>
                </Children>
            </GridLayout>
        </Children>
    </UIFigure>
    <AppDetails>
        <Name>My App</Name>
        <Version>1.0</Version>
    </AppDetails>
    <InternalData>
        <AppId>GENERATE-A-UUID-HERE</AppId>
    </InternalData>
    <!-- Thumbnail is used by file previewers. To change how the thumbnail is captured or stored, use the App Details dialog box in App Designer. -->
    <Thumbnail autoCapture='true'></Thumbnail>
</MATLABApp>
```

## App with Two-Panel Layout (Responsive)

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<MATLABApp schemaVersion='1.0.0' release='R2026b.0' minRelease='R2026b'>
    <UIFigure name='UIFigure'>
        <AutoResizeChildren>'off'</AutoResizeChildren>
        <Name>'Responsive App'</Name>
        <Position>[100 100 800 500]</Position>
        <Children>
            <GridLayout name='MainGrid'>
                <ColumnSpacing>6</ColumnSpacing>
                <ColumnWidth>{250, '1x'}</ColumnWidth>
                <Padding>[6 6 6 6]</Padding>
                <RowHeight>{'1x'}</RowHeight>
                <RowSpacing>6</RowSpacing>
                <Children>
                    <Panel name='ControlPanel'>
                        <AutoResizeChildren>'off'</AutoResizeChildren>
                        <Layout>
                            <Column>1</Column>
                            <Row>1</Row>
                        </Layout>
                        <Title>'Controls'</Title>
                        <Children>
                            <GridLayout name='ControlGrid'>
                                <ColumnWidth>{'1x'}</ColumnWidth>
                                <Padding>[10 10 10 10]</Padding>
                                <RowHeight>{'fit'}</RowHeight>
                                <RowSpacing>6</RowSpacing>
                                <Children>
                                    <Button name='RunButton'>
                                        <ButtonPushedFcn>RunButtonPushed</ButtonPushedFcn>
                                        <Layout>
                                            <Column>1</Column>
                                            <Row>1</Row>
                                        </Layout>
                                        <Text>'Run'</Text>
                                    </Button>
                                </Children>
                            </GridLayout>
                        </Children>
                    </Panel>
                    <Panel name='DisplayPanel'>
                        <AutoResizeChildren>'off'</AutoResizeChildren>
                        <Layout>
                            <Column>2</Column>
                            <Row>1</Row>
                        </Layout>
                        <Title>'Output'</Title>
                        <Children>
                            <GridLayout name='DisplayGrid'>
                                <ColumnWidth>{'1x'}</ColumnWidth>
                                <Padding>[10 10 10 10]</Padding>
                                <RowHeight>{'1x'}</RowHeight>
                                <Children>
                                    <UIAxes name='MainAxes'>
                                        <Layout>
                                            <Column>1</Column>
                                            <Row>1</Row>
                                        </Layout>
                                    </UIAxes>
                                </Children>
                            </GridLayout>
                        </Children>
                    </Panel>
                </Children>
            </GridLayout>
        </Children>
    </UIFigure>
    <RunConfiguration>
        <StartupFcn>startupFcn</StartupFcn>
    </RunConfiguration>
    <AppDetails>
        <Name>Responsive App</Name>
        <Version>1.0</Version>
    </AppDetails>
    <InternalData>
        <AppId>GENERATE-A-UUID-HERE</AppId>
    </InternalData>
    <!-- Thumbnail is used by file previewers. To change how the thumbnail is captured or stored, use the App Details dialog box in App Designer. -->
    <Thumbnail autoCapture='true'></Thumbnail>
</MATLABApp>
```

## App with Tabs

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<MATLABApp schemaVersion='1.0.0' release='R2026b.0' minRelease='R2026b'>
    <UIFigure name='UIFigure'>
        <AutoResizeChildren>'off'</AutoResizeChildren>
        <Name>'Tabbed App'</Name>
        <Position>[100 100 640 480]</Position>
        <Children>
            <GridLayout name='MainGrid'>
                <ColumnWidth>{'1x'}</ColumnWidth>
                <Padding>[10 10 10 10]</Padding>
                <RowHeight>{'1x'}</RowHeight>
                <Children>
                    <TabGroup name='TabGroup'>
                        <Layout>
                            <Column>1</Column>
                            <Row>1</Row>
                        </Layout>
                        <Children>
                            <Tab name='InputTab'>
                                <AutoResizeChildren>'off'</AutoResizeChildren>
                                <Title>'Input'</Title>
                                <Children>
                                    <GridLayout name='InputTabGrid'>
                                        <ColumnWidth>{'1x'}</ColumnWidth>
                                        <Padding>[10 10 10 10]</Padding>
                                        <RowHeight>{'fit'}</RowHeight>
                                        <Children>
                                            <EditField name='DataEditField'>
                                                <Layout>
                                                    <Column>1</Column>
                                                    <Row>1</Row>
                                                </Layout>
                                            </EditField>
                                        </Children>
                                    </GridLayout>
                                </Children>
                            </Tab>
                            <Tab name='ResultsTab'>
                                <AutoResizeChildren>'off'</AutoResizeChildren>
                                <Title>'Results'</Title>
                                <Children>
                                    <GridLayout name='ResultsTabGrid'>
                                        <ColumnWidth>{'1x'}</ColumnWidth>
                                        <Padding>[10 10 10 10]</Padding>
                                        <RowHeight>{'1x'}</RowHeight>
                                        <Children>
                                            <UIAxes name='ResultAxes'>
                                                <Layout>
                                                    <Column>1</Column>
                                                    <Row>1</Row>
                                                </Layout>
                                            </UIAxes>
                                        </Children>
                                    </GridLayout>
                                </Children>
                            </Tab>
                        </Children>
                    </TabGroup>
                </Children>
            </GridLayout>
        </Children>
    </UIFigure>
    <AppDetails>
        <Name>Tabbed App</Name>
        <Version>1.0</Version>
    </AppDetails>
    <InternalData>
        <AppId>GENERATE-A-UUID-HERE</AppId>
    </InternalData>
    <!-- Thumbnail is used by file previewers. To change how the thumbnail is captured or stored, use the App Details dialog box in App Designer. -->
    <Thumbnail autoCapture='true'></Thumbnail>
</MATLABApp>
```

## Value Formatting Rules

| Type | Format | Example |
|------|--------|---------|
| String | Single-quoted char literal | `'Hello World'` |
| Number | Bare numeric | `42` or `3.14` |
| Boolean | Bare `true` or `false` | `true` |
| Position | Bracketed 4-element array | `[100 100 640 480]` |
| Color (RGB) | Bracketed 3-element array (0-1) | `[0.94 0.94 0.94]` |
| Cell array | Braces with quoted elements | `{'Option A', 'Option B'}` |
| Numeric array | Bracketed space-separated | `[1 2 3 4 5]` |
| On/Off | Single-quoted | `'on'` or `'off'` |
| Callback | Bare function name | `ButtonPushed` |

## Character Escaping

In element values: `<` → `&lt;`, `>` → `&gt;`, `&` → `&amp;`

In attribute values: `'` → `&apos;`, `<` → `&lt;`, `>` → `&gt;`, `&` → `&amp;`

----

Copyright 2026 The MathWorks, Inc.

----
