# Salesforce Schema Auditor

Salesforce Schema Auditor leverages Salesforce's [Tooling API](https://developer.salesforce.com/docs/atlas.en-us.api_tooling.meta/api_tooling/intro_api_tooling.htm) and [Schema Class](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_schema.htm) to gather metadata on your organization's Objects, Fields, and Record Types. Examples of metadata are created/last modified date and user, description, helptext, etc. A complete list of currently available metadata can be found [here](#here).


## Getting Started

These instructions will get you a copy of the project up and running on your Salesforce instance.

 ##### Import classes and VF pages manually or using [Salesforce DX](https://developer.salesforce.com/platform/dx) 
 
 To add them manually, I recommend using the Developer Console to add the class(s) and VisualForce page(s) at the same time

```
Setup > Apex Classes > Developer Console
```

##### Set the VisualForce Page(s) to _Available for Lightning Experience, Lightning Communities, and the mobile app_

```
Setup > VisualForce Pages > Edit (select the checkbox on the VF pages you need)
```

##### Add Remote Site Settings with your instance url

```
Setup > Remote Site Settings > New > add instance URL and save with defaults
```

Your instance URL should use the following form:
```
https://your-instance-name.my.salesforce.com
```
_Note: If you enter an incorrect instance URL, you'll get an error when running the audit that will display the correct URL it's trying to hit, at which point you can update your Remote Site Setting with the proper URL. The URL form provided applies to Sandbox orgs, so running the auditor in other environments may require another form._


 ##### <a name="available"></a>Create a new Lightning App and add a VisualForce page component to it that links to the audit you want to use. 

Choose a 'One Region' view so that the auditor results table takes up the whole screen. If you can't find your VF page in the dropdown list when you try to add the component, you may have forgotten to set it to [_Available for Lightning Experience, Lightning Communities, and the mobile app_](#available).


 ```
 Setup > Lightning App Builder > New > App Page
 ```
Save and activate your Lightning app when done.

You should now be able to search for your Lightning App and run the audit against your org! 

## Deployment

I recommend running this in a SandBox since you can create a copy of your org and it works the same as if you were running it on your production org. If you plan to re-run this over time, however, you may consider putting it in a stage environment that gets refreshed regularly. Also note that the Object Auditor record counts may be inaccurate if your Sandbox does not copy over records from Production.

## <a name="here"></a>Currently Available Metadata

| Field Auditor    | RecordType Auditor    | Object Auditor             |
|:-----------------|:----------------------|:-------------------------- |
|Field Id          |Corresponding Object   |Durable Id                  |
|Field Label       |RecordType Label       |Object Label                |
|Field API Name    |RecordType API Name    |Plural Label                |
|Field Description |Description            |API Name                    |
|Field HelpText    |IsActive?              |Description                 |
|Created By        |Created By             |Record Count                |
|Last Modified By  |Last Modified By       |Created By                  |
|Created Date      |Created Date           |Last Modified By            |
|Last Modified Date|Last Modified Date     |Created Date                |
|                  |                       |Last Modified Date          |


## Contributing

This project is unmonitored. Contributions are not accepted at this time.

 
## Authors

* [Tristyn Maalouf](https://github.com/tristyn-maalouf)
* [Kevin Jerauld](https://github.com/airtightspring)


## License

This project is licensed under the Apache 2.0 License. See [LICENSE.md](./LICENSE) for more info.


