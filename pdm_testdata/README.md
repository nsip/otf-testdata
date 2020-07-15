## Progress Data Management Test Data

Various sample files to mimic 3rd party data inputs to the OTF.
Also sample maps used by services to align and scale assessment results.

All data is synthetic, all maps are incorrect - they prove that mapping is viable but have no actual value in terms of equating inputs and outputs.

```
├── BrightPath.json.brightpath //sample complex json requires map & inference
├── MathsPathway.csv //sample csv that requires mapped resolution
├── README.md
├── maps
│   ├── alignmentMaps
│   │   ├── nlpLinks.csv // links between any token/id and an NNLP
│   │   └── providerItems.csv // links from provider items to e.g. AC
│   └── levelMaps
│       ├── scaleMap.csv // drives calculation of national scaling
│       └── scoresMap.csv // resolves mapped scores e.g. A-F = 100..600
├── sreams.mapped.csv // simple csv but complex grade (1-many)
├── sreams.prescribed.csv // simple csv but NNLP aware
├── xapi.literacy.json // xapi observations 
└── xapi.numeracy.json // xapi observations

```

Data is for development and testing only, and is subject to sigificant change.
