# FIM Workbench

FIM Workbench is a MATLAB add-on for testing how faults affect a Simulink model. Give it a model (`.slx` or `.mdl`) and it generates a separate, editable model with fault switches at compatible signal connections and operator blocks. Each switch starts off. Choose which faults to activate, set their values and time windows, then compare the working copy against an all-off run using the same model inputs. The comparison exports time-stamped waveforms for each output, the settings and the inputs used.

For example, an automatic transmission model takes throttle and brake commands and outputs vehicle speed, engine RPM, and gear. You can run the same driving inputs twice, with and without a throttle fault, to measure its effect.

## Install and run

1. Download `FIMWorkbench-2.2.1.mltbx`. Double-click it in the MATLAB Files panel and select **Install**. [Download the installer](https://github.com/31916/FIMWorkbench/releases/download/v2.2.1/FIMWorkbench-2.2.1.mltbx)
2. Open **FIMWorkbench** from the **Apps** tab, or enter `FIMWorkbench` in the MATLAB Command Window.
3. Select **PM** and **Open benchmark** to try the included pacemaker model. To use your own, open its usual Simulink project or run its initialization script. Choose the **Source model**, give the **Working copy** a new filename and optionally select a **Fault profile** JSON. Leave the profile blank to instrument all compatible sites. Select **Create working copy**.
4. In **Fault settings**, search by block name, signal name, port or site ID. Select a row and choose **Show in model** to highlight the installed block and its outgoing signal. The **Fault type** menu shows the choices for that row. Edit the value, time window and **On** switch. Choose **Compare off / on** and a results directory to run both simulations and open their waveforms. Choose **Save model** to keep your edits. Use **Open saved copy...** to return to your own model.

FIM Workbench requires **MATLAB R2026a or later and Simulink**. Install any additional products the model uses, such as Stateflow or Deep Learning Toolbox. The verification results below were obtained on Linux with R2026a. When the installation path contains non-ASCII characters, Workbench loads the SB network weights from a temporary copy for the current MATLAB session. To uninstall, remove **FIM Workbench** in MATLAB's Add-Ons manager. Working copies live in your own working folder. [MathWorks add-on installation guide](https://www.mathworks.com/help/matlab/matlab_env/get-add-ons.html)

### Benchmark data

PM works directly from the installer. For the other 11 research models, extract the matching source checkout and select its top-level folder the first time **Open benchmark** prompts for it. MATLAB remembers that folder. A source checkout can use all 12 in place. The installer contains the PM authors' MIT notice. Check the contributor terms for the other models and weights before sharing copies. [v2.2.1 source ZIP](https://github.com/31916/FIMWorkbench/archive/refs/tags/v2.2.1.zip) · [Third-party terms](THIRD_PARTY.md)

From the command line, register the data once with `fimwb.benchmarkFolder('AT','/path/to/FIMWorkbench-2.2.1')`. To try a comparison using PM alone, open **PM**, search for `PACE_COUNT`, select the connection ending at the root output (`E623_1__621_inport1`), choose `bias`, enter `2`, enable it and select **Compare off / on**. Select the PACE_COUNT output in the plot to see its two-count offset.

## Try the automatic transmission example

Open a fresh working copy of the AT model after connecting the benchmark data from the command line.

~~~matlab
[window, file] = fimwb.openBenchmark('AT', fullfile(pwd,'AT_example'));
open_system(file)
~~~

The editor lists 101 compatible sites. Search for `throttle`. To reproduce a throttle signal stuck at zero, select **E84_1__1_inport2**, the branch from `throttle` to `Engine`. Choose `zero`, set **Start (s)** to `5` and **Stop (s)** to `10`, and select **On**. With the bundled driving inputs, the following values were observed at 9 seconds. Turning the fault off reproduced all three baseline output traces over the full 33-second run. [AT site catalogue](verification/arch2026/AT/sites.json)

| Output at 9 s | Baseline | Throttle fault on |
|---|---:|---:|
| Vehicle speed | 43.66 mph | 19.63 mph |
| Engine speed | 2,445 rpm | 600 rpm |
| Gear | 3 | 2 |

With `fimwb.openBenchmark('AT')`, Workbench keeps the editable copy under `FIMWorkbench/AT/` in your MATLAB `userpath`, or under `prefdir` if `userpath` is empty. The second return value, `file`, gives the full path. Reopening the same folder restores saved settings. To use a working copy from an older ZIP distribution, pass its `work/AT/` folder as the second argument.

Other supported models are `AFC`, `NN`, `CC`, `SC`, `PM`, `F16`, and `SB1` through `SB5`. Available faults depend on the signal type, sample time, dimensions, and block type at each site.

## FIM fault catalogue

Workbench implements the 10 signal faults and five operator mutations from **FIM (Fault Injection and Mutation for Simulink)** by Ezio Bartocci, Leonardo Mariani, Dejan Ničković, and Drishti Yadav. It is an independent implementation that builds the faults from standard Simulink blocks. Workbench provides site discovery, the editor, and model generation. [Research paper (ESEC/FSE 2022)](https://doi.org/10.1145/3540250.3558932) · [Authors' implementation](https://gitlab.com/DrishtiYadav/fimtool/-/tree/a110acf2b718eab4cdf65f938203f60009fa0510) · [Original fault definitions](https://gitlab.com/DrishtiYadav/fimtool/-/blob/a110acf2b718eab4cdf65f938203f60009fa0510/FaultInjector_Master/Readme.txt)

| FIM name | Workbench `type` | Effect or setting |
|---|---|---|
| Negate | `negate` | Reverse the sign of the input. |
| Invert | `invert` | Output 1 for a zero input and 0 for a nonzero input. |
| Stuck-at 0 | `zero` | Set the signal to zero. |
| Absolute | `absolute` | Output the absolute value. |
| Noise | `noise` | Add band-limited white noise. Set its power with `value`, its sample period in seconds with `period`, and its random seed with `seed`. |
| Bias/Offset | `bias` | Add the signed offset in `value`. |
| Stuck-at | `hold_last` | Hold the last value before the fault starts. At time zero, use `value` as the initial value. Continuous signals use the previous major solver step. |
| Time Delay | `delay` | Delay the signal by `value` seconds. The initial output is zero. For discrete signals, use a multiple of the source sample period. |
| Bit Flip | `bit_flip` | Flip a Boolean signal. |
| Package Drop | `package_drop` | Replace the signal with `value` while the fault is active. |
| Relational Operator Replacement (ROR) | `ror` | Select `>`, `<`, `<=`, `>=`, `==`, or `~=`. |
| Logical Operator Replacement (LOR) | `lor` | Select `AND`, `OR`, `NAND`, `NOR`, `XOR`, or `NXOR` (exclusive NOR). |
| Sum to Product (S2P) | `s2p` | Replace a sum block with a product. |
| Product to Sum (P2S) | `p2s` | Replace a product block with a sum. |
| Arithmetic Sign Replacement (ASR) | `asr` | Set one sign per operand. For two operands, choose `+-`, `--`, `++`, or `-+`. |

JSON and MATLAB configurations accept the original FIM fault names. ROR, LOR, and ASR also accept the original one-based operator numbers in the order shown above. For example, `"type":"LOR","value":6` selects `NXOR`. Workbench adds two more types, for a total of 17. Use `gain` to multiply by a factor, or `stuck_at` to hold a user-specified constant.

Faults are active from `start` (inclusive) to `stop` (exclusive), in seconds. The default is the whole simulation. Leave **Stop (s)** blank in the editor or omit `stop` in JSON to keep the fault active until simulation ends. For a fixed duration, set `stop` to the start time plus the duration.

For a logical replacement, open **AFC** and select `O1688`. Choose `XOR` from the replacement menu and select **On**. The equivalent JSON fault for a five-second window is `{"site":"O1688","type":"lor","enabled":true,"value":"XOR","start":5,"stop":10}`. The menu lists alternatives compatible with the selected inputs. For example, a scalar, single-input `NOT` supports `AND` and `OR`. Single-input vector reductions offer replacements that preserve the output shape.

## Use your own model and combine faults

Make sure the source model compiles with its usual initialization scripts, data dictionaries, and referenced libraries. Run `fimwb.scan` to get the site IDs used in a configuration. The `source` and `destinations` fields identify the wiring. The `faults` and `reason` fields show the available faults and the reason for an exclusion. Scan again after changing the model structure.

~~~matlab
tool = fileparts(which('FIMWorkbench'));
data = fimwb.benchmarkFolder('AT');
addpath(fullfile(data,'verification','sources','at_data'))
src = fullfile(data,'verification','sources','ARCH','transmission','Autotrans_shift.mdl');
sites = fimwb.scan(src);
list = struct2table(sites,'AsArray',true);
disp(list(:,{'id','kind','source','dataType','reason'}))

out = fullfile(pwd,'work');
if ~isfolder(out), mkdir(out); end
file = fullfile(out,'my_at.mdl');
fimwb.build(src,fullfile(tool,'examples','at-combination.json'),file)
fimwb.editor(file)
~~~

Choose a new output filename for `build`. The sample configuration targets `E106_1__51_inport2`, the **brake-to-Vehicle** branch. When both entries below are on, Workbench applies them in order and the signal becomes `(input + 1) * 1.25`. Entries at different sites can be active together. A fault on the common stem reaches all branches, and branch-specific faults then act on their respective connections. An operator block has one replacement slot. [Sample configuration](examples/at-combination.json)

~~~json
{
  "faults": [
    {"site":"E106_1__51_inport2","type":"bias","enabled":true,"value":1},
    {"site":"E106_1__51_inport2","type":"gain","enabled":false,"value":1.25}
  ]
}
~~~

You can change a slot from MATLAB between simulation runs. Slot `2` below corresponds to the second fault in the configuration.

~~~matlab
load_system(file)
fimwb.setFault('my_at',2,struct('enabled',true,'value',1.5))
fimwb.setFault('my_at',1,struct('start',2,'stop',5))
save_system('my_at')
~~~

Workbench scans the active Simulink hierarchy, including subsystem ports, editable wiring under masks and library links, common stems, and individual branches. To test the internals of a referenced model, supply that model as the source. Bias and gain support integer signals up to 32 bits, with results rounded and saturated to the source type. Compatible real vectors support elementwise transformations such as bias and gain.

## Compare outputs and run combinations

**Compare off / on** runs an all-off baseline and one case containing the current editor settings, including unsaved fault edits. For a campaign, select a row, check **Sweep off/on**, enter a JSON array in **Sweep values**, or do both. Repeat on other rows and select **Run campaign**. For example, sweeping off/on on one wire and bias values `[-2,0,2]` on a second runs six cases plus one baseline. A value axis activates that slot unless it also has an off/on axis. Other slots keep their editor settings in every case. The button shows the case count before you run. **Clear axes** clears the campaign selections.

The same workflow is available from MATLAB. In the AT working copy, slot numbers can be found in the editor or the verified site table. This example uses the throttle and brake branches discussed above.

~~~matlab
[win,file] = fimwb.openBenchmark('AT',fullfile(pwd,'AT_example'));
sites = readtable(fullfile(fimwb.benchmarkFolder('AT'),'verification','all_sites','AT','sites.csv'),'TextType','string');
throttle = sites.slot(sites.site=="E84_1__1_inport2");
brake = sites.slot(sites.site=="E106_1__51_inport2");
fimwb.setFault('edit_at',throttle,struct('type','zero','start',5,'stop',10));
fimwb.setFault('edit_at',brake,struct('type','bias'));
axesToTry = struct('slot',{throttle,brake},'field',{'enabled','value'}, ...
                   'levels',{[false true],[-2 0 2]});
run = fimwb.experiment(file,fullfile(pwd,'AT_six_cases'),axesToTry);
fimwb.plotComparison(run.folder)
~~~

Omit the third argument for a single off/on comparison. Choose a fresh output folder for each experiment. The first axis changes fastest. The editor records a fault case that fails to simulate, keeps its diagnostic and continues with the remaining cases. In the plot, a failed case shows the baseline and its diagnostic. The MATLAB API defaults to stopping on an error. Pass `fimwb.experiment(file,folder,axesToTry,[],'record')` to use the editor's behavior. A failed baseline or cancellation discards the incomplete experiment. The model's fault settings are restored in each mode.

| Output | Contents |
|---|---|
| `baseline.csv`, `case_0001.csv`, … | One row per output component and native sample time. Columns are `time_s`, `signal`, `component`, `value` and `imaginary`. Each run keeps its solver time grid. |
| Matching `.mat` files | Simulink datasets with native data types, dimensions and precision. The comparison uses root Outports, or logged signals for a model without root Outports. |
| `experiment.json`, `baseline.json`, `case_*.json` | Model name and on-disk file hash, MATLAB release, initial slot settings, axes and per-case overrides. Each case maps its signal numbers to the logged block path and port. Search for a signal or block in the comparison window. |
| `runs.csv` | Completion status and diagnostic for each simulation. Successful cases have CSV and MAT traces. |
| `inputs.mat` | Root external inputs evaluated once before simulation and the MATLAB random generator state replayed for each case. |

The experiment uses the loaded model's settings and a finite stop time. New working copies record a relative link to the source model when both files are on the same drive. Opening the copy through Workbench makes its companion MAT files and classes in the original folder available for the lifetime of the model. Keep the relative layout when moving a project. For older copies, open the original Simulink project or add its model folder to the MATLAB path. Inputs supplied by external hardware, the wall clock, or side effects in custom callbacks must be recorded or made deterministic by the model owner for a repeatable comparison.

## Generate single-fault model files

Specify the values to try in a profile. `plan` enumerates compatible single-fault configurations and reports excluded settings. `sweep` generates and compiles a model for each selected case. Supply a fourth argument to `sweep` to run a subset. The example below generates every planned case. [Included profiles](examples/profiles.json)

~~~matlab
profiles = fullfile(tool,'examples','profiles.json');
[cases, excluded] = fimwb.plan(src,profiles);
results = fimwb.sweep(src,profiles,fullfile(out,'sweep'));
~~~

Each case has a folder containing the model, configuration JSON, and checksums. Repeating the sweep reuses verified outputs. Results record `compiled`, `reused`, or `failed` and any error message. To combine selected faults, pass `struct('faults',cases([i,j]))` to `fimwb.build` with the source and a new output path. Open either kind of generated model with `fimwb.editor`.

## Build from source or upgrade

Clone the repository, set the MATLAB current folder to its root, and run `FIMWorkbench`. To build the installer, run the following commands from the same folder.

~~~matlab
addpath(fullfile(pwd,'packaging'))
installer = build_fimworkbench_toolbox(fullfile(pwd,'dist'))
~~~

Distribute the `.mltbx` file from `dist/`. The source for this release is tagged `v2.2.1`.

Install an update the same way as a new release. **Open saved copy...** reopens models with their saved settings. To pick up injection sites added since a working copy was created, generate a fresh copy from the source with a new filename. For a fresh AFC benchmark, close any open AFC working copy and run `fimwb.openBenchmark('AFC',fullfile(pwd,'AFC_new'))` with a new folder. Scripts written for 1.0.0 should use the `FIMWorkbench` launcher and the `fimwb.` function prefix.

## ARCH-COMP verification

The suite covers all 12 models in the **2026 ARCH-COMP Falsification category**, counting the five SB models separately. PM uses the authors' `Model1_Scenario1_Faulty` baseline with its LRL input and PACE_COUNT output. The SB copies load the five competition models and their trained weights from the selected benchmark folder. For F16, a Simulink block calls the official MATLAB ODE with the project's R2026a compatibility code. F16 coverage is limited to its single observation signal. [Competition report](https://easychair.org/publications/paper/DtZ3/open) · [ARCH models](https://gitlab.com/goranf/ARCH-COMP/-/tree/2238327987e2e3b81f9bcc38b2ad250013deba04/models/FALS) · [PM source](https://github.com/3MD3/3MD3/blob/5a1688de66b1974f6f07362495ccc0cfba957124/Model1/Scenario1.m) · [SB source](https://github.com/lyudeyun/FalBenchGen_ARCHCOMP25/tree/4d4729f428780a8a01bc0173873506c8d71a9f38)

| Check | Recorded result |
|---|---|
| Site installation | 923 of 967 candidates retained an independent fault slot after saving and recompiling. With all slots off, every model reproduced its original output values and time vectors over the full run. The other 44 candidates comprised 34 unsupported connections and 10 internal SB wires regenerated by prediction blocks. Each model's `verification/all_sites/<model>/sites.csv` records the slot or exclusion reason. |
| Active faults | All 105 representative trace checks had zero maximum absolute error against the expected transformation. Cases included bias, gain, combinations, retuning and disabling faults, and internal injections on the 11 native Simulink models. [Per-model results](verification/results.csv) |
| Editor | Tested search, highlighting, per-site fault menus, invalid edits, saving and reopening on all 12 models. Compared 305,934 values in baseline/fault CSV exports with the reference runs. [Editor results](verification/editor.csv) |
| Factorial experiments | Four configurations per benchmark produced 48 verified cases. Across those cases and their 12 baselines, 765,107 output values matched the independent references. F16 exercised its single observation site. The synthetic two-site campaign also checked eight configurations, input replay and cancellation. [Synthetic results](verification/campaign.csv) · [ARCH-COMP campaign results](verification/arch_campaign.csv) |
| Campaign size | The bundled profiles enumerate 12,957 single-fault settings. Each model's `fault_plan.csv` lists the cases. The `verification/arch2026/<model>/traces.mat` files contain recorded waveforms for the representative simulations. |
| Logical replacements | All 22 applicable replacements at five AFC sites matched direct changes to the original Simulink logical operator across 112,200 local output samples and 1,072,588 model output samples. [LOR results](verification/lor.csv) |
| Fault semantics | Synthetic models exercised all 15 FIM types and the two Workbench extensions, including all six LOR truth tables for two inputs, six ROR alternatives, four two-input ASR sign patterns, combined faults, time windows, and array signals. The largest absolute error across 53 comparisons was about 4.77 × 10⁻⁷ in the single-precision noise power test. [Fault-type results](verification/fault_types/results.csv) |

To reproduce the checks, add the benchmark scripts to your MATLAB path with `addpath(fullfile(fileparts(which('FIMWorkbench')),'benchmarks'))`. Run the full-suite checks from a source checkout and give each run a fresh output directory.

| MATLAB call | What it checks |
|---|---|
| `run_arch_suite(outputFolder)` | Representative fault configurations and output traces on all 12 models |
| `check_all_sites(outputFolder)` | Installation of every compatible site and all-off behavior |
| `test_fault_types(outputFolder)` | Fault semantics, parameters, and application order |
| `verify_editor(outputCsv)` | Model editing and persistence on all 12 benchmarks |
| `verify_experiment(outputCsv)` | Factorial order, levels, frozen inputs, plotting and restoration after cancellation |
| `verify_arch_campaign(outputCsv)` | Four combinations and a baseline on each of 12 benchmarks |
| `verify_arch_lor(outputCsv)` | Every applicable LOR setting against a direct block replacement |

The source lock records the upstream commits and SHA-256 hashes. From a source checkout, run `python3 benchmarks/fetch_sources.py` to verify the bundled files. When fetching missing project-specific inputs, use `--project /path/to/project` to point to the project containing the original dependencies. [Source lock](benchmarks/source-lock.json)

## Run the original FIM paper model

The evaluation in Section 4 and Table 2 of Bartocci et al. uses the Aircraft Elevator Control System (AECS). With the authors' pinned checkout, select `Aircraft_fault_injector/sf_aircraft_model/Aircraft.slx` as the source and `examples/fim-paper-aecs.json` as the fault profile. This creates one editable working copy containing all 45 locations from the paper. The included verification runs each location individually and compares the observed waveform with its expected transformation. [Reproduction and measured results](verification/fim_paper/README.md) · [Authors' source](https://gitlab.com/DrishtiYadav/fimtool/-/tree/a110acf2b718eab4cdf65f938203f60009fa0510) · [Paper](https://doi.org/10.1145/3540250.3558932)

## Evaluating usability and reusing the code

The paired study includes a generated model, two tasks, four balanced trial schedules, an independent waveform grader and per-attempt timing. A scripted run exercised the original FIM and Workbench on both tasks. Human completion times and error rates remain to be measured. [Study protocol and results](study/README.md)

The original Workbench implementation is MIT-licensed. The research models and their generated copies follow the terms of their respective contributors. [MIT license](LICENSE) · [Third-party licenses and attribution](THIRD_PARTY.md)
