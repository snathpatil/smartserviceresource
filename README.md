# Smart Service Resource
This repository contains a batch class that we can use to maintain Service Resources in Salesforce Scheduler app by using simple CSVs. This is a single batch class that can operate on different data sources.

<a href="https://githubsfdeploy.herokuapp.com">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

>For more information, please visit : [UnofficialSF : Salesforce Scheduler](https://unofficialsf.com/scheduler-service-resource-onboarding "UnofficialSF : Salesforce Scheduler")

# Quick Steps
>If you want to run this code as-is, you need existing data in a certain format. Of course, you can modify this code according to your need.

You need to have skills added to your org. Below is the sample data which is used in this example:
SkillName|SkillDeveoperName|Description| 
| :---: | :---: | :---: | 
|Wealth Management |Wealth Management_English||
|Wealth Management|Wealth Management_German||
| Wealth Management| Wealth Management_Korean||
|General Banking| General Banking_English||
|Business Banking| Business Banking_English||

Make sure you have created Service Resource CSV as:
|UserName| 
| :---: | 
|ryan.dobson@example.com|
|rachel.adams@example.com|
|karl.schmidt@example.com|
|jacob.smith@example.com|
|jessie.park@example.com|

Service Resource Skill CSV as:
|UserName|SkillName|Language|SkillStartDate| 
| :---: | :---: | :---: | :---: | 
|ryan.dobson@example.com|Business Banking |English|2021-04-30T17:30:00.000+0000|
|rachel.adams@example.com|General Banking|English|2020-12-04T00:00:00.000+0000|
|karl.schmidt@example.com| Wealth Management| German|2020-08-08T00:00:00.000+0000|
|jacob.smith@example.com|  Wealth Management| German|2018-02-04T00:00:00.000+0000|
|jessie.park@example.com|Wealth Management| Korean|2019-11-09T00:00:00.000+0000|

Service Territory Member CSV as:
|UserName|TerritoryName|TerritoryStartDate|OperatingHoursName| TerritoryType
| :---: | :---: | :---: | :---: | :---: | 
|ryan.dobson@example.com|Market Street Branch |2021-01-10T00:00:00.000+0000|Morning Shift Market Street|P|
|rachel.adams@example.com|Market Street Branch|2020-12-04T00:00:00.000+0000|Operating Hours Market Street|P|
|karl.schmidt@example.com| Market Street Branch| 2021-05-19T00:00:00.000+0000|Morning Shift Market Street|P|
|karl.schmidt@example.com| Golden Gate Avenue| 2020-08-08T00:00:00.000+0000|Afternoon Shift Golden Gate Ave|S|
|jacob.smith@example.com|  Market Street Branch| 2018-02-04T00:00:00.000+0000|Morning Shift Market Street|P|
|jessie.park@example.com|Market Street Branch| 2019-11-09T00:00:00.000+0000|Afternoon Shift Market Street|P|

## Execution

Once you have all the CSV files ready, add those in **Static Resource** in your org. 
- To execute code for **ServiceResource**:

```apex
SmartServiceResourceContainer myBatchObject = new SmartServiceResourceContainer('<STATIC_RESOURCE_NAME>', 'ServiceResource'); 
Id batchId = Database.executeBatch(myBatchObject);
```

- To execute code for **ServiceResourceSkill**:

```apex
SmartServiceResourceContainer myBatchObject = new SmartServiceResourceContainer('<STATIC_RESOURCE_NAME>', 'ServiceResourceSkill'); 
Id batchId = Database.executeBatch(myBatchObject);
```

- To execute code for **ServiceTerritoryMember**:

```apex
SmartServiceResourceContainer myBatchObject = new SmartServiceResourceContainer('<STATIC_RESOURCE_NAME>', 'ServiceTerritoryMember'); 
Id batchId = Database.executeBatch(myBatchObject);
```
