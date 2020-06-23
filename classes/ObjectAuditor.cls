/*
 * ****************************************************************************
 * Description : ObjectAuditor class gathers metadata on all custom and some
 *               (common) standard objects and displays it in the ObjectAuditView
 * 				 VisualForce page
 * *****************************************************************************/


public class ObjectAuditor {
    
    public class ObjectData {
        public String durableId {get; set;}
        public String label {get; set;}
        public String labelPlural {get; set;}
        public String apiName {get; set;}
        public String description {get; set;}
        public Integer recordCount {get; set;}
        public String createdBy {get; set;}
        public String createdDate {get; set;}
        public String lastModifiedBy {get; set;}
        public String lastModifiedDate {get; set;}
    }
    
    public List<ObjectData> resultsList {get; set;}
    private Map<String,ObjectData> resultsMap {get; set;} // maps by id
    private Map<String,ObjectData> apiNameMap {get; set;} // maps by api names
    private Set<String> commonStandardObjects = new Set<String>{'Account','AccountBrand','Approval','Asset','Audience','Calendar','Campaign','CampaignMember','Case','Contact','Contract','Employee','Expense','Event','Goal','Lead','Macro','Opportunity','Order','Partner','Pricebook2','Product2','Survey','Task','User'};
    public Integer cSOListSize {get; set;}
    
    public void init(){
        cSOListSize = commonStandardObjects.size();
    }
        
    public void queryObjects(){
  		//temp lists for sorting purposes
  		List<ObjectData> standardResults = new List<ObjectData>();
        List<ObjectData> customResults = new List<ObjectData>();
  		
        resultsList = new List<ObjectData>();
        resultsMap = new Map<String,ObjectData>();
        apiNameMap = new Map<String,ObjectData>();
        
        // Query 1
        String queryString = 'SELECT DurableId, DeveloperName, MasterLabel, PluralLabel, QualifiedApiName FROM EntityDefinition WHERE IsCustomSetting = false'; 
        List<EntityDefinition> results = new List<sObject>(Database.query(queryString));
       
        for(EntityDefinition e : results){
        	ObjectData oData = new ObjectData();
	
            oData.label = e.MasterLabel;
            oData.labelPlural = e.PluralLabel;
            oData.apiName = e.QualifiedApiName;
            oData.durableId = e.DurableId;
            
            //filter out everything we don't want and protect against collection size error
            if(resultsList.size() == 1000 || oData.durableId.contains('.') || oData.durableId.contains('ChangeEvent') || 
               (!oData.apiName.contains('__c') && !commonStandardObjects.contains(oData.apiName))){continue;}
                 
            if(oData.apiName.contains('__c')){
                customResults.add(oData);
            } else {
                standardResults.add(oData);
            }
            
            resultsMap.put(oData.durableId, oData);
            apiNameMap.put(oData.apiName, oData);
            
        }
        
        // Establish HTTP connection
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionID());
        req.setHeader('Content-Type', 'application/json');
        Http h = new Http();        
        
        // Gather our instance name to use for calls to the Tooling API
        String instanceName = System.Url.getSalesforceBaseUrl().toExternalForm();
              
        // Query 2 - Get Id, DeveloperName, Description, CreatedBy.Name, CreatedDate, LastModifiedBy.Name, LastModifiedDate from custom objects
        req.setEndpoint(instanceName + '/services/data/v48.0/tooling/query/?q=Select+Id,DeveloperName,Description,CreatedBy.Name,CreatedDate,LastModifiedBy.Name,LastModifiedDate+From+CustomObject');
        req.setMethod('GET');
        HttpResponse res1 = h.send(req);
        String responseBody = res1.getBody(); 
        
        // Deserialize the response into an object
        Map<String, Object> payload1 = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
        
        for (Object data : (List<Object>)payload1.get('records')){
            Map<String, Object> record = (Map<String, Object>)data;
            
            String id = (String)record.get('Id');
            String formalizedId = id.substring(0,id.length() - 3);
            
            ObjectData oData = resultsMap.get(formalizedId);
            
            if(oData != null){
                String lastModifiedName, createdName;
                
                // Custom objects in a managed package do not include these details, so only attempt to add them if the createdByObject is not null
                Object createdByObject = (Object)record.get('CreatedBy');
                if(createdByObject != null){
                    Map<String, Object> createdByMap = (Map<String, Object>)createdByObject;
                    createdName = (String)createdByMap.get('Name');
                } 
                
                Object lastModifiedByObject = (Object)record.get('LastModifiedBy');
                if(lastModifiedByObject != null){
                    Map<String, Object> LastModifiedByMap = (Map<String, Object>)LastModifiedByObject;
                    lastModifiedName = (String)LastModifiedByMap.get('Name');
                }
                
                oData.description = (String)record.get('Description');
                oData.createdDate = formatDateTime((String)record.get('CreatedDate'));
                oData.lastModifiedDate = formatDateTime((String)record.get('LastModifiedDate'));
                oData.createdBy = createdName;
                oData.lastModifiedBy = lastModifiedName;
            }
        }
        
   		// Request 3 - get the record count
		req.setEndpoint(instanceName + '/services/data/v48.0/limits/recordCount');
        req.setMethod('GET');
        HttpResponse res2 = h.send(req);
        String responseBody2 = res2.getBody();
        
        Map<String, Object> payload2 = (Map<String, Object>)JSON.deserializeUntyped(responseBody2);
        
        for (Object data : (List<Object>)payload2.get('sObjects')){
            Map<String, Object> record = (Map<String, Object>)data;
            
            Integer recordCount = (Integer)record.get('count');
            String apiName = (String)record.get('name');
            
            ObjectData o = apiNameMap.get(apiName);
            if(o != null){ 
            	o.recordCount = recordCount;
            }            
        }
        
        standardResults = sortByLabel(standardResults);
        customResults = sortByLabel(customResults);
        
        resultsList.addAll(standardResults);
        resultsList.addAll(customResults);
    }
    
     /**
     * Quicksort algorithm to sort the custom and standard results lists by object label
     * adapted from http://improveit360.blogspot.com/2010/09/implementing-quicksort-to-sort-list-of.html
     */
    private List<ObjectData> sortByLabel(List<ObjectData> records){
        if(records == null || records.size() <= 1)
            return records;
            
        List<ObjectData> Less = new List<ObjectData>();
        List<ObjectData> Greater = new List<ObjectData>();
        integer pivot = records.size() / 2;
          
        ObjectData pivotValue = records.get(pivot);
        records.remove(pivot);
        
        for(ObjectData x : records)
        {
            if(x.label <= pivotValue.label)
                Less.add(x);
            else if(x.label > pivotValue.label)
                Greater.add(x);   
        }
        
        List<ObjectData> returnList = new List<ObjectData>();
        returnList.addAll(sortByLabel(Less));
        returnList.add(pivotValue);
        returnList.addAll(sortByLabel(Greater));
        return returnList;
    }
    
    // Format UTC Date from queries into a more readable form
    private String formatDateTime(String utcDate){
    	return utcDate.substring(0,utcDate.length() - 12).replace('T', ' ');
    } 
}