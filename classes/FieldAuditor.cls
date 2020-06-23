/*
 * ****************************************************************************
 * Description : The FieldAuditor class gathers metadata on a selected object's 
 *               fields and renders the audit results in the FieldAuditView
 * 				 VisualForce page
 * *****************************************************************************/

public class FieldAuditor {
    
    public class FieldAuditData {
        public String fieldLabel { get; set;}
        public String durableId {get; set;}
        public String apiName { get; set;} 
        public String dataType { get; set;}
        public String description { get; set;}
        public String helpText { get; set;}
        public String createdBy { get; set;}
        public String lastModifiedBy { get; set;}
        public String createdDate { get; set;}
        public String lastModifiedDate { get; set;}
        public String developerName {get; set;}
        public Boolean isCustom {get; set;}
    
	}

    public List<SelectOption> availableObjects {get; set;}  // picklist options containing list of objects in our org
    public List<FieldAuditData> resultsList {get; set;}    	// list of results (for displaying in VF table)
    public String selectedObject {get; set;}                // object selected from VF picklist or input in the text field
    
    public Integer numResults {get; set;}     // displayed on frontend
    public String isCustomObject {get; set;}  // displayed on frontend 
              
    private List<string> SFObjectList {get; set;}            			// all objects in our org
    private Map<String, FieldAuditData> results{ get; set;} 			// main map of our field data results (See FieldAuditData class for more info on that object)
      
    // fields that we have identified to be system fields that should be ignored by the audit
    private Set<String> blacklistedFields = new Set<String>{'CompletedDateTime','RecurrenceRegeneratedType','RecurrenceMonthOfYear','RecurrenceInstance','RecurrenceDayOfMonth','RecurrenceDayOfWeekMask','RecurrenceType','RecurrenceTimeZoneSidKey','RecurrenceEndDateOnly','RecurrenceStartDateOnly	','RecurrenceActivityId','ReminderDateTime','ActivityOriginType','ArchivedDate','IsArchived','IsClosed','PrioritySortOrder','IsHighPriority','AccountId','Jigsaw Contact Id','ReportsToName','EmailBouncedReason','EmailBouncedDate','IsEmailBounced','JigsawContactId','Id','IsDeleted','CreatedDate','LastModifiedDate','SystemModstamp','LastActivityDate','LastViewedDate','LastReferencedDate','UserRecordAccessId','MasterRecordId','AccountSource','IsCssEnabled','CssLastLoginDate','CompareName','PhotoUrl','CompareSite','OwnerAlias','JigSawCompanyId','ConnectionReceivedDate','ConnectionSentDate','AccountRollupId','ProductIsArchived'};		
    
    /**
     * Called OnLoad of the FieldAuditor app
     * 
     * Uses GlobalDescribe to get a list of the objects within our org and create a picklist of the object labels as well as a list of their API names
     */
    public void getAllSFObjects(){
        // intialize picklist, object name list, and map connecting the picklist options to that objects API name
        availableObjects = new List<SelectOption>();
        SFObjectList = new List<String>();
        Map<String, String> picklistOptions = new Map<String, String>();
       
        for(Schema.SObjectType obj : Schema.getGlobalDescribe().Values()){
            Schema.DescribeSObjectResult objData = obj.getDescribe(SObjectDescribeOptions.DEFERRED);
            String name = objData.getName();

            /*
             * These conditions can be used to filter out background SF objects if you don't want to see them in the picklist, but also have the potential
             * to filter out some objects we do want to see, so use precaution when choosing which limiters to include
             *
			 * Complete list of limiters:
             * objData.getLabel() != objData.getLabelPlural() && !obj.getDescribe().isCustomSetting() && obj.getDescribe().getRecordTypeInfos().size() > 0 && obj.getDescribe().isCreateable() &&
             * !name.containsignorecase('history') && !name.containsignorecase('tag') && !name.containsignorecase('share') && !name.containsignorecase('feed')
             */
            
            // add the object's API name to our master list
            SFObjectList.add(name);
                
            // picklists can only handle 1000 entries, so if the picklist has space, add its key value mapping here
            if(picklistOptions.size() < 1000){
                picklistOptions.put(name, objData.getLabel());
            }
        }
		
        // Create our actual picklist options and add them to availableObjects
        for(String s : picklistOptions.keySet()){
            availableObjects.add(new SelectOption(s, picklistOptions.get(s)));
        }
        availableObjects = SortOptionList(availableObjects);
    }
    
    /**
     * Called when the user selects an option from the picklist or enters one in the text field and clicks Submit
     * 
     * This function utilizes the Tooling API and the SalesForce Schema class to perform the audit
     */
    public void gatherFieldData(){ 
        
        // get schema of our org and object, and then get the object's field map
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe(); 
        Schema.SObjectType OppSchema = schemaMap.get(selectedObject);
        Map<String, Schema.SObjectField> fieldMap = OppSchema.getDescribe().fields.getMap(); 
        
        //initialize temp lists (will be used for sorting later)
        List<FieldAuditData> standardResults = new List<FieldAuditData>();
        List<FieldAuditData> customResults = new List<FieldAuditData>();
                
        // initialize or reset results map for this query
        results = new Map<String, FieldAuditData>(); 
        numResults = 0;

        // Establish HTTP connection
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionID());
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('GET');
        Http h = new Http(); 
        
        // Gather our instance name to use for calls to the Tooling API
        String instanceName = System.Url.getSalesforceBaseUrl().toExternalForm();

        // QUERY 1 - Get the object's Id and Field's Label, API Name, Data Type, and Description on all fields of the selected object
        req.setEndpoint(instanceName + '/services/data/v48.0/tooling/query/?q=Select+EntityDefinition.DurableId,Label,DeveloperName,DurableId,QualifiedApiName,DataType,Description+from+FieldDefinition+Where+EntityDefinition.QualifiedApiName=\'' + selectedObject + '\'');       
        HttpResponse res1 = h.send(req);
        String responseBody = res1.getBody(); 
       
        String objectId = null;
        
        // Deserialize the response into an object and create a FieldAuditData object for each record in our response 
        Map<String, Object> payload1 = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
        
        for (Object data : (List<Object>)payload1.get('records'))
        {
            Map<String, Object> record = (Map<String, Object>)data;

            // for the first field, get the objectId (all the following will have the same objectId)
            if(objectId == null){
                // for columns in our query that use dot notation, we have to first translate the object into a sub-object and then get the data from that
                Object entityDefinition = (Object)record.get('EntityDefinition');
                Map<String, Object> eDefMap = (Map<String, Object>)entityDefinition;
                objectId = (String) eDefMap.get('DurableId');
            }
           
            FieldAuditData fData = new FieldAuditData();
            fData.fieldLabel = (String)record.get('Label');
            fData.developerName = (String)record.get('DeveloperName');
            fData.durableId = (String)record.get('DurableId');
            fData.apiName = (String)record.get('QualifiedApiName');
            if(blacklistedFields.contains(fData.apiName)){
            	continue;	// system field - ignore
            }
            fData.dataType = (String)record.get('DataType');
            fData.description = (String)record.get('Description');
  
            // add field record to proper list for sorting purposes later and assign isCustom, inline help text (for standard fields only)
            if(fData.apiName.contains('__c')){
                customResults.add(fData);
                fData.isCustom = true;
            } else {
                standardResults.add(fData);
                fData.isCustom = false;
                if(fieldMap.containsKey(fData.developerName)){ 
                	Schema.DescribeFieldResult f = fieldMap.get(fData.developerName).getDescribe();
                    fData.helpText = f.getInlineHelpText();
                }            	
            } 
            
            // Put our partially-filled FieldAuditData object into our results map with the DurableId as its key
            results.put(fData.durableId, fData);
        }
        
        // QUERY 2 - Get the Id, InlineHelpText, CreatedBy.Name, LastModified.Name, CreatedDate, LastModifiedDate on all CUSTOM fields of this object
        req.setEndpoint(instanceName + '/services/data/v48.0/tooling/query/?q=Select+Id,InlineHelpText,CreatedDate,LastModifiedDate,LastModifiedBy.Name,CreatedBy.Name+from+CustomField+Where+TableEnumOrId=\'' + objectId + '\'');
        HttpResponse res2 = h.send(req); 
        responseBody = res2.getBody();
        
        // Deserialize the response into an object and create a FieldAuditData object for each record in our response
        Map<String, Object> payload2 = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
        
        for (Object data : (List<Object>)payload2.get('records'))
        {
            Map<String, Object> record = (Map<String, Object>)data;
            
            Object createdByObject = (Object)record.get('CreatedBy');
            Map<String, Object> createdByMap = (Map<String, Object>)createdByObject;
            String createdName = (String) createdByMap.get('Name');
            
            Object lastModifiedByObject = (Object)record.get('LastModifiedBy');
            Map<String, Object> LastModifiedByMap = (Map<String, Object>)LastModifiedByObject;
            String lastModifiedName = (String) LastModifiedByMap.get('Name');
            
            // the ID for Custom field adds 3 characters to the end so they get removed here so that it matches its record from FieldDefinition query
            String fieldId = (String)record.get('Id');
            String formalizedFieldId = objectId + '.' + fieldId.substring(0,fieldId.length() - 3);
            
            if(results.containsKey(formalizedFieldId)){
                FieldAuditData f = results.get(formalizedFieldId);
                f.helpText = (String)record.get('InlineHelpText');
                f.createdDate = formatDateTime((String)record.get('CreatedDate'));
                f.lastModifiedDate = formatDateTime((String)record.get('LastModifiedDate'));
                f.lastModifiedBy = lastModifiedName;
                f.createdBy = createdName;
            }
        }
        
        //sort each list by field label and then add them to final results list
        standardResults = sortByLabel(standardResults);
        customResults = sortByLabel(customResults);
        
        resultsList = new List<FieldAuditData>();
        resultsList.addAll(standardResults);
        resultsList.addAll(customResults);

        // Displayed on the Frontend
        isCustomObject = OppSchema.getDescribe().isCustom() ? 'Custom Object' : 'Standard Object';
        numResults = resultsList.size();
    }
    
    /**
     * Quicksort algorithm to sort the custom and standard results lists by field label
     * adapted from http://improveit360.blogspot.com/2010/09/implementing-quicksort-to-sort-list-of.html
     */
    private List<FieldAuditData> sortByLabel(List<FieldAuditData> records){
        if(records == null || records.size() <= 1)
            return records;
            
        List<FieldAuditData> Less = new List<FieldAuditData>();
        List<FieldAuditData> Greater = new List<FieldAuditData>();
        integer pivot = records.size() / 2;
          
        FieldAuditData pivotValue = records.get(pivot);
        records.remove(pivot);
        
        for(FieldAuditData x : records)
        {
            if(x.fieldLabel <= pivotValue.fieldLabel)
                Less.add(x);
            else if(x.fieldLabel > pivotValue.fieldLabel)
                Greater.add(x);   
        }
        
        List<FieldAuditData> returnList = new List<FieldAuditData>();
        returnList.addAll(sortByLabel(Less));
        returnList.add(pivotValue);
        returnList.addAll(sortByLabel(Greater));
        return returnList;
    }
    
    /** 
     * This is a simple quicksort algorithm to sort a SelectOption list (dropdown) 
     * by label alphabetically. source: http://improveit360.blogspot.com/2010/09/implementing-quicksort-to-sort-list-of.html
     */
    private List<SelectOption> SortOptionList(List<SelectOption> ListToSort)
    {
        if(ListToSort == null || ListToSort.size() <= 1)
            return ListToSort;
            
        List<SelectOption> Less = new List<SelectOption>();
        List<SelectOption> Greater = new List<SelectOption>();
        integer pivot = ListToSort.size() / 2;
          
        // save the pivot and remove it from the list
        SelectOption pivotValue = ListToSort[pivot];
        ListToSort.remove(pivot);
        
        for(SelectOption x : ListToSort)
        {
            if(x.getLabel() <= pivotValue.getLabel())
                Less.add(x);
            else if(x.getLabel() > pivotValue.getLabel()) 
                Greater.add(x);   
        }
        List<SelectOption> returnList = new List<SelectOption> ();
        returnList.addAll(SortOptionList(Less));
        returnList.add(pivotValue);
        returnList.addAll(SortOptionList(Greater));
        return returnList; 
    }  
    
    // Format UTC Date from queries into a more readable form
    private String formatDateTime(String utcDate){
    	return utcDate.substring(0,utcDate.length() - 12).replace('T', ' ');
    } 
}