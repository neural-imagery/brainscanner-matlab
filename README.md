Read the docx

On M1 Mac, install Matlab 2023b or later (tested to work). On older Macs, ask Claude given your OS what to install. The minimum version for the software on windows is 2019b (2019b is tested to work, 2018a as mentioned in the documentation does NOT work). The original author develops on 2022a.

```
git config fetch.recurseSubmodules on-demand
git clone https://github.com/neural-imagery/brainscanner-matlab
cd BrainRecordIR
git pull --recurse-submodules
git submodule init
git submodule update
```

Ensure that there are now files inside the nirs-toolbox folder inside brainrecordIR. If nirs-toolbox is still empty, try directly
```
git clone https://github.com/huppertt/nirs-toolbox
```
instead of git submodules.

Now, double click BrainRecordIR.mlapp to open it in MATLAB and run the code. In MATLAB, right click nirs toolbox and hit add to path then hit the option to add all submodules and subfolders. You may have to run, from within the MATLAB terminal, instead of the default BrainRecordIR,

```
BrainRecordIR('SIMULATOR', 'SIMULATOR')
```
or
```
BrainRecordIR('BT_NIRS', 'BT_NIRS')
```

depending on what you want.
