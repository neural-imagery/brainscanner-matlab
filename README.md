Read the docx

Ensure nirs-toolbox is a folder inside brainrecordIR. 

On M1 Mac, install Matlab 2023b or later. On older Macs, ask Claude given your OS what to install. The minimum version for the software on windows is 2019b (2018a as mentioned in the documentation does NOT work).

```
git config fetch.recurseSubmodules on-demand
git clone https://github.com/huppertt/BrainRecordIR/
cd BrainRecordIR
git pull --recurse-submodules
```

Double click BrainRecordIR.mlapp to open it in MATLAB and run the code. In MATLAB, right click nirs toolbox and hit add to path then hit the option to add all submodules and subfolders. You may have to run, from within the MATLAB terminal, instead of the default BrainRecordIR,

```
BrainRecordIR('SIMULATOR', 'SIMULATOR')
```
or
```
BrainRecordIR('BT_NIRS', 'BT_NIRS')
```

depending on what you want.