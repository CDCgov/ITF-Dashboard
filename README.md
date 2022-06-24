# ITF Dashboard Data Pipeline
[![ITF Internal Dashboard Refresh](https://github.com/CDCgov/ITF-Dashboard/actions/workflows/automated_dashboard_update.yaml/badge.svg)](https://github.com/CDCgov/ITF-Dashboard/actions/workflows/automated_dashboard_update.yaml)

This document has completed governance review per local and agency processes. This material is a draft.

## Project Description:

This project is a repository housing R functions and scripts used in the US Centers for Disease Control and Prevention (CDC) COVID-19 Response International Task Force (ITF) COVID-19 Dashboard

As part of the CDC COVID-19 Response, the ITF Situational Awareness & Visualization (SAVI) Team has created and maintains an interal Power BI Dashboard to assist Task Force and response leadership with situational awareness of the global pandemic and response. The dashboard contains analyses of the most updated global case and testing data from multiple sources. The Power BI report that generates the dashboard runs multiple R scripts in order to refresh, process and update the data as CSV files which are then imported into Power BI for visualizations. The R functions in this project are used to read in case and testing data, apply algorithms and populate the underlying data tables of the report. Access to this dashboard is currently limited to CDC staff only.

The ITF has also created several curated Power BI views of global data on the public CDC COVID Data Tracker (https://covid.cdc.gov/covid-data-tracker/#global-counts-rates) to communicate to the general public the types of analyses that CDC is conducting using international data. The code saved to this repository would be used to populate the data underlying those views in a Power BI Dashboard.

## GitHub Actions Workflow

### Scheduling

The update process is scheduled for 1935 UTC (1535 EDT) Monday Thru Friday.  

- This can be altered by changing the Cron settings on [automated_dashboard_update.yaml#L7.](https://github.com/CDCgov/ITF-Dashboard/blob/master/.github/workflows/automated_dashboard_update.yaml#L7)  

- [Read more about Cron time in GitHub Actions here](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule).  

### Altering the Workflow

By default, the GHA workflow runs the three R scripts mentioned above, and any changes made to those scripts on the master branch will automatically propagate to the workflow.  

- If you need to add an additional step, or modify the workflow for any reason, the process is defined in: [.github/workflows/automated_dashboard_update.yaml](https://github.com/CDCgov/ITF-Dashboard/blob/master/.github/workflows/automated_dashboard_update.yaml).  

- If you want to create a new workflow altogether, you can define a new .yaml script in the `.github/workflows` folder.  

### Debugging the Workflow

Occasionally, the GHA workflow will encounter and error during processing.  

- [You should be able to check the status of the workflow here](https://github.com/CDCgov/ITF-Dashboard/actions/workflows/automated_dashboard_update.yaml).  

- If you notice an error, you can click on the failed job to view the log files to identify where the error occurred. Most of the time, this is just a simple web request issue.  

- [If the error is ephemeral, you can try re-running the pipeline from the actions tab](https://docs.github.com/en/actions/managing-workflow-runs/re-running-workflows-and-jobs).  

### Manually triggering the GHA Workflow  

You might want to trigger the workflow manually if you want data updates quicker than the scheduled refresh.

- You should be able to hit the `"Run Workflow"` button on [this page](https://github.com/CDCgov/ITF-Dashboard/actions/workflows/automated_dashboard_update.yaml) to trigger the pipeline  
- [Read more about this method here](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)


## Manual SOP

This applies to cloning this repository and running the pipeline manually.  

### Prerequisites

#### Renv

This project uses {renv} to handle R package dependencies. When you clone the repo, you'll need to run the following to install all dependencies before proceeding:

```r
renv::restore()
```

- [Read more about {renv} here](https://rstudio.github.io/renv/articles/renv.html)

#### Azure Data Lake Credentials

The final write-out process requires an Azure Service Principle to transfer files to the Data Lake location. The GitHub Actions automation has these credentials stored internally, but you can request personal access from the current ITF-SAVI Lead.

- **Credentials are not strictly required to process the data, but you will be unable to write out the data to the Data Lake and update the dashboards without it.**

#### Passing Data Lake Credentials via Environment Var

If you run this locally, you'll need to **create a .env file in the root directory**.  
The .env file contains environmental variables needed to connect and write files to the Data Lake.

The file should be parsed line-by-line and expected to have the following format:
```
AZURE_DL_PATH=XXXXX/XXXXXX
AZURE_TENANT_ID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
AZURE_APP_ID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
AZURE_APP_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXX-XXXXXXXX
```

- If you need assistance with this step, please contact the ITF-SAVI Team to request the .env file.

### Processing Steps

There are 3 steps in the processing pipeline:  
1. Pulling and processing data for all internal dashboards [(itf_dashboard/0_output_data.R)](https://github.com/CDCgov/ITF-Dashboard/blob/master/itf_dashboard/0_output_data.R)
1. Pulling and processing data for all external dashboards [(covid_data_tracker/0_output_data.R)](https://github.com/CDCgov/ITF-Dashboard/blob/master/covid_data_tracker/0_output_data.R)
1. Writing out data to Azure Data Lake [(export_data.R)](https://github.com/CDCgov/ITF-Dashboard/blob/master/.github/workflows/export_data.R)

The GitHub Actions workflow runs the first two at the same time and waits until they're complete to run the last one.

- **Running the pipeline manually, you should ensure that you've run the first two data pull steps before attempting to export.** 

- If the data export script is successful, you should be able to see the files in Data Lake with an updated timestamp.  

### Data sources referenced:
The project uses several publicly-available data sources, including:

#### The COVID-19 Data Repository by the Center for Systems Science and Engineering (CSSE) at Johns Hopkins University, cases and Deaths data sets:
- https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_global.csv

- https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv

- More info here: https://github.com/CSSEGISandData/COVID-19

- and here: https://coronavirus.jhu.edu/map.html

Citation: Dong E, Du H, Gardner L. An interactive web-based dashboard to track COVID-19 in real time. Lancet Inf Dis. 20(5):533-534. doi: 10.1016/S1473-3099(20)30120-1

#### The World Health Organization COVID-19 Global data set:

- https://covid19.who.int/WHO-COVID-19-global-data.csv
- More info here: https://covid19.who.int/

#### Our World In Data Testing data set (Until 6/23/2022):

- https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/owid-covid-data.csv

- More info here: https://ourworldindata.org/coronavirus-testing

- Even more info here: https://github.com/owid/covid-19-data/blob/master/public/data/README.md

Citation: Max Roser, Hannah Ritchie, Esteban Ortiz-Ospina and Joe Hasell (2020) - "Coronavirus Pandemic (COVID-19)". Published online at OurWorldInData.org. Retrieved from: 'https://ourworldindata.org/coronavirus' [Online Resource]

#### FIND Testing data set:

- https://raw.githubusercontent.com/dsbbfinddx/FIND_Cov_19_Tracker/master/input_data/cv_data_download.csv

- More info here: https://www.finddx.org/covid-19/test-tracker/

#### Standardized population data:

- https://www.cia.gov/library/publications/the-world-factbook/fields/335rank.html

#### Continent classifications:

- https://pkgstore.datahub.io/JohnSnowLabs/country-and-continent-codes-list/country-and-continent-codes-list-csv_csv/data/b7876b7f496677669644f3d1069d3121/country-and-continent-codes-list-csv_csv.csv                       


## Public Domain

This repository constitutes a work of the United States Government and is not subject to domestic copyright protection under 17 USC § 105. This repository is inthe public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

## License

The repository utilizes code licensed under the terms of the Apache Software
License and therefore is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under
the terms of the Apache Software License version 2, or (at your option) any
later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the Apache Software License for more details.

You should have received a copy of the Apache Software License along with this
program. If not, see http://www.apache.org/licenses/LICENSE-2.0.html

The source code forked from other open source projects will inherit its license.

## Privacy

This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
Surveillance Platform [Disclaimer](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md)
and [Code of Conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/privacy.html](http://www.cdc.gov/privacy.html).

## Contributing

Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page are subject to the [Presidential Records Act](http://www.archives.gov/about/laws/presidential-records.html)
and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records

This repository is not a source of government records, but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).

## Notices

Please refer to [CDC's Template Repository](https://github.com/CDCgov/template)
for more information about [contributing to this repository](https://github.com/CDCgov/template/blob/master/CONTRIBUTING.md),
[public domain notices and disclaimers](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md),
and [code of conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).

