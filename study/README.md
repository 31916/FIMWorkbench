# Compare original FIM and FIM Workbench

This four-trial exercise measures how long the same participant takes to produce the requested output with each tool, and how many submitted models need correction. It uses a two-wire Simulink fixture generated locally. Both sensor signals equal time, sampled every 0.01 s from 0 to 10 s. The tasks request a +2 bias on Reading A from 1 s and a −3 bias on Reading B from 2 s. Each participant performs both tasks in both tools.

## Prepare a participant session

Use MATLAB and Simulink R2026a. Obtain the original FIM source at commit `a110acf2b718eab4cdf65f938203f60009fa0510`. The harness copies the original scripts and block library into a fresh, disposable folder for each FIM trial. That tool saves its library and recreates its output directory during injection. [Original FIM source](https://gitlab.com/DrishtiYadav/fimtool/-/tree/a110acf2b718eab4cdf65f938203f60009fa0510)

~~~matlab
% The add-on puts fimwbStudy on the path. In a checkout, run addpath('study').
session = fullfile(pwd,'participant_01');
schedule = fimwbStudy('prepare',session,1,'/path/to/fimtool');
~~~

Assign consecutive participant numbers. Four schedules balance both tool order and task order. Use the same machine, MATLAB version, documentation access and practice time for each tool. Before timing, explain the controls on a separate practice model. Choose a common time limit in advance, for example 10 minutes. Record the participant's prior Simulink and FIM experience under an anonymous identifier.

## Run a trial

1. Close models and libraries from the previous trial. Run `trial = fimwbStudy('start',session,n)` for trial numbers 1 through 4 in order. This displays the task, returns the source path and starts the clock. Calling it again shows the same task and keeps the original start time.
2. For **Workbench**, use **Create working copy** on `trial.source`. Find the requested wire in the editor, choose `bias`, enter its value and start time, enable it and save the copy.
3. For **FIM**, work inside `trial.folder`. Complete the single-row `Configuration/sites.csv` and `Configuration/enable.csv` inputs. The upstream spelling for the bias is `Bias/Offset` and the open-ended effect is `Infinite time`. Run `FISingle('model.csv','injections')` followed by `FCSingle('model.csv','injections','enable.csv')`. The generated model is `fixture/fim_study_plant_copy.slx`. [Upstream workflow](https://gitlab.com/DrishtiYadav/fimtool/-/blob/a110acf2b718eab4cdf65f938203f60009fa0510/Readme.md)
4. Submit the saved candidate with `attempt = fimwbStudy('submit',session,n,candidateFile)`. The same grader simulates both outputs and checks all 2,002 values against the task equation, with a maximum absolute error below 1e-9. A failed submission records the error and permits a retry. If the time limit is reached or the participant stops, run `fimwbStudy('stop',session,n)` to close the trial and retain its outcome.

Each `trial_*/attempts.csv` records tool, task, submission number, elapsed seconds, grading seconds, outcome and waveform error. Elapsed time includes the participant's repairs and excludes the grader's simulation time. Retain stopped trials when reporting completion rates. For participants who finish both versions of a task, report paired differences in time and failed submissions, the number of pairs, and their range. Report incomplete pairs separately. Running `prepare` produces a schedule and blank fixtures. Human measurements begin when a participant starts a trial.

## Scripted reference run

~~~matlab
rows = verify_fim_study('/path/to/fimtool',fullfile(pwd,'fim_comparison.csv'));
~~~

On Linux with R2026a, Workbench reproduced both requested waveforms with maximum absolute error below 2e-15. Running the pinned original `FISingle` and `FCSingle` produced maximum errors of 8 for task A and 13 for task B. On this fixture the original mask wrote the chosen offset and effect selector to the library definition. The disconnected instance retained an offset of 10 and its pulse selector. Applying the two parameters to that instance reproduced the requested waveforms. The test records the direct and corrected outcomes separately and checks that an unchanged model fails both tasks. If participants have access to this workaround, give everyone the same instructions and record that choice. [Script and instance correction](verify_fim_study.m) · [Recorded results](../verification/fim_comparison.csv)

The `scripted_setup_s` column measures one automated setup run per tool and task. MATLAB startup, caching and trial order affect those times. A human usability or speed claim requires participant measurements.
