# A Machine Learning-based Targeted Demand Response Framework to Mitigate Price Volatility and Enhance Grid Resilience in Electricity Markets

## Suggested Citation 
- Please cite the following paper when you use this data hub:  
`
citation info
`


## Features
- This repository contains two parts: 
	1) Synthetic ERCOT grid, processed public demand, solar, wind, or hydro profiles in 2020
	2) Source code to run Security-Constrained Unit Commitment (SCUC), Security-Constrained Economic Dispatch (SCED) and Demand Response program


## Navigation
This public Github repository contains two components: source data and codes. We navigate this data hub as follows.

- `code` contains the source code to run SCUC, SCED and Demand Response Programs. The main files are `run_SCUC.m` and `run_SCEDR.m` in which they both depend on MatPower and Gurobi. With these dependencies installed and appropriate results folder directories specified, two main files can be ran without any changes. However, since SCED requires unit commitment schedules, users want to execute `run_SCUC.m` first and then execute `run_SCEDR.m`.

- `data` contains additional generator data and profiles (such as demand, solar, wind, and hydro) taken from the public open-access data set and used in the simulation in the paper. 

## Contact Us
Please contact us if you need further technical support or search for cooperation. Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.\
Email contact: &nbsp; [Le Xie](mailto:le.xie@tamu.edu?subject=[GitHub]%20DR_Framework), &nbsp; [Kiyeob Lee](mailto:kiyeoblee@tamu.edu?subject=[GitHub]%20DR_Framework), &nbsp; [Siva Seetharaman](mailto:sivaranjani@tamu.edu?subject=[GitHub]%20DR_Framework).
