# MATLAB Analysis of Electrically Stimulated Muscle-Like Cells

MATLAB pipeline developed for the quantitative analysis of contraction
and movement in reprogrammed muscle cells subjected to electrical
stimulation.

## Experimental conditions

Three stimulation frequencies are analysed:

- 1 Hz
- 50 Hz
- 100 Hz

Each video is divided into:

- Before stimulation: 0–10 s
- During stimulation: 10–20 s
- After stimulation: 20–30 s

## Analysis

The pipeline performs:

- Video preprocessing
- Manual ROI and cell selection
- Cellular pattern tracking
- Contraction detection
- Contraction frequency calculation
- Contraction displacement calculation
- Contraction speed calculation
- Global displacement and speed analysis
- Statistical analysis
- Scatter plot and heatmap generation

## Requirements

- MATLAB
- Image Processing Toolbox
- Signal Processing Toolbox
- Statistics and Machine Learning Toolbox

## Usage

Place the experimental videos in a folder named `OFICIAL`.

Videos must follow the naming convention:

- vidA (1) -> 1 Hz
- vidA (2) -> 50 Hz
- vidA (3) -> 100 Hz

Run:

allVideoAnalysis.m

## Output

The pipeline generates an Excel workbook containing the analysed metrics
and statistical summaries, together with graphical results.

## Author

Clara Cembranos Martínez

Bachelor's Thesis – Biomedical Engineering

Universidad Carlos III de Madrid / Instituto Cajal CNC-CSIC
