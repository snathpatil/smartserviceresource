/**
BSD 3-Clause License

Copyright (c) 2021, Shantinath Patil
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

global class SmartServiceResourceContainer implements Database.Batchable<String>, Database.Stateful {
	global String vFileName = '';
	global String vLoadType = '';

	global String warningCsvHeader = '';
	global String warningCsvBody = '';
	global String warningEmailBody = '';
	global String warningSsvName = '';

	global String errorCsvHeader = '';
	global String errorCsvBody = '';
	global String errorEmailBody = '';
	global String errorSsvName = '';

	public SmartServiceResourceContainer(String pFileName, String pLoadType) {
		if (pFileName != null) {
			vFileName = pFileName;
		}
		if (pLoadType != null) {
			vLoadType = pLoadType;
		}
	}

	global Iterable<String> start(Database.BatchableContext bc) {
		if (Test.isRunningTest()) {
		  List<String> resourceList = new List<String>();
		  resourceList.add('tester.ls.temp@salesforce.com.test.7457457441, Analytics, Test, Test, Test');
		  return resourceList;
		}
		List<StaticResource> defaultResource = [SELECT Body
		                                          FROM StaticResource
		                                         WHERE Name = :vFileName];
		blob tempB = defaultResource[0].Body;
		String contentFile = tempB.toString();
		String[] filelines = contentFile.split('\n');
		filelines.remove(0); // This will remove CSV header
		return filelines;
	}

	global void execute(Database.BatchableContext bc, List<String> filelines) {
		if (vLoadType == 'ServiceResource') {
		  	addServiceResource(filelines);
		}
		if (vLoadType == 'ServiceResourceSkill') {
		  	addServiceResourceSkill(filelines);
		}
		if (vLoadType == 'ServiceTerritoryMember') {
		  	addServiceTerritoryMember(filelines);
		}
	}

	global void finish(Database.BatchableContext bc) {
		if (warningEmailBody != '') {
			Messaging.EmailFileAttachment csvAttc1 = new Messaging.EmailFileAttachment();
			blob csvBlob = Blob.valueOf(warningCsvBody);
			csvAttc1.setFileName(warningSsvName);
			csvAttc1.setBody(csvBlob);

			Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
			email.setSubject(warningSsvName);
			email.setTargetObjectId(UserInfo.getUserId());
			email.saveAsActivity = false;
			email.setSenderDisplayName('DF2U Data Load');
			email.setPlainTextBody(warningEmailBody);
			email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ csvAttc1 });
			Messaging.SendEmailResult[] r = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
		}

		if (errorEmailBody != '') {
			Messaging.EmailFileAttachment csvAttc1 = new Messaging.EmailFileAttachment();
			blob csvBlob = Blob.valueOf(errorCsvBody);
			csvAttc1.setFileName(errorSsvName);
			csvAttc1.setBody(csvBlob);

			Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
			email.setSubject(errorSsvName);
			email.setTargetObjectId(UserInfo.getUserId());
			email.saveAsActivity = false;
			email.setSenderDisplayName('DF2U Data Load');
			email.setPlainTextBody(errorEmailBody);
			email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ csvAttc1 });
			Messaging.SendEmailResult[] r = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
		}
	}

  	public void addServiceResource(List<String> filelines) {
  		Set<String> vSetStringUserNames = new Set<String>();
		for (Integer i = 0; i < filelines.size(); i++) {
		    String[] inputvalues = filelines[i].split(',');
		    vSetStringUserNames.add((inputValues[0]).replaceAll('\r\n|\n|\r'.toLowerCase(), ''));
		}
		if(!vSetStringUserNames.isEmpty()) {
			if(warningCsvHeader == '') {
		        warningCsvHeader = 'UserName, Message \n';
		        warningCsvBody += warningCsvHeader;
		        warningSsvName = 'ServiceResource.csv';
      		}
			List<ServiceResource> vListServiceResource = new List<ServiceResource>();
			Map<String, User> vMapUserToId = new Map<String, User>();
			for (User vUser : [SELECT Id, UserName, Name
			                     FROM User
			                    WHERE UserName IN :vSetStringUserNames
			]) {
			    vMapUserToId.put(vUser.UserName, vUser);
			}
			for (String vUserName : vSetStringUserNames) {
			    if (vMapUserToId.containsKey(vUserName)) {
			        ServiceResource vResource = new ServiceResource();
			        vResource.RelatedRecordId = vMapUserToId.get(vUserName).Id;
			        vResource.ResourceType = 'T';
			        vResource.Name = vMapUserToId.get(vUserName).Name;
			        vResource.IsActive = true;
			        vListServiceResource.add(vResource);
			    } else {
					if (checkHeapLimit()) {
						warningEmailBody = 'Service Resource mismatch! Please validate attached data and load again!';
						warningCsvBody += vUserName + ', Username not found!\n';
					}
				}
			}
			vSetStringUserNames.clear();

			Database.SaveResult[] SR = Database.insert(vListServiceResource, false);

			if (errorCsvHeader == '') {
		        errorCsvHeader = 'RelatedRecordId, ResourceType, Name, IsActive, ErrorMessage \n';
		        errorCsvBody += errorCsvHeader;
		        errorSsvName = 'ServiceResource.csv';
		    }
			for (Integer i = 0; i < SR.size(); i++) {
				if (!SR[i].isSuccess() && checkHeapLimit()) {
				//only look at failures, or NOT Successes
				errorEmailBody = 'Service Resource insert error! Please validate attached data and load again!';
				errorCsvBody += vListServiceResource[i].RelatedRecordId + ', ' +
					            vListServiceResource[i].ResourceType +', ' +
					            vListServiceResource[i].Name +', ' +
					            vListServiceResource[i].IsActive +', "' +
					            SR[i].getErrors() +'"\n';
				}
			}
		}
  	}

  	public void addServiceResourceSkill(List<String> filelines) {
  		Set<String> vSetStringUserNames = new Set<String>();

		for (Integer i = 0; i < filelines.size(); i++) {
			String[] inputvalues = filelines[i].split(',');
			vSetStringUserNames.add((inputValues[0]).replaceAll('\r\n|\n|\r', ''));
		}

		//First fetch all Service Resource records based in first column
		Map<String, Id> vMapServiceResourceToUserName = new Map<String, Id>();
		Map<String, Id> vMapSkillNameToId = new Map<String, Id>();
		if (!vSetStringUserNames.isEmpty()) {
			for (ServiceResource vServiceResource : [SELECT Id, Name, RelatedRecord.UserName
			                                     	   FROM ServiceResource
			                                    	  WHERE RelatedRecord.UserName IN :vSetStringUserNames
			]) {
				vMapServiceResourceToUserName.put(vServiceResource.RelatedRecord.UserName, vServiceResource.Id);
			}
		}
		vSetStringUserNames.clear();

		//Get all the skills based in the org. 
		//We can even fetch only limited number of skills from second column of CSV.
		for (Skill vSkill : [SELECT Id, DeveloperName FROM Skill]) {
			vMapSkillNameToId.put(vSkill.DeveloperName, vSkill.Id);
		}

		List<ServiceResourceSkill> vListServiceResourceSkill = new List<ServiceResourceSkill>();
		List<ServiceResourceSkill> vListMissingInfo = new List<ServiceResourceSkill>();

		//To make sure we have unique combination of skill matching
		Set<String> vSetDeDup = new Set<String>(); 

		//Now iterate over all the data in CSV rows.
		for (Integer i = 0; i < filelines.size(); i++) {
			String[] inputvalues = filelines[i].split(',');
			String firstCol = (inputValues[0]).replaceAll('\r\n|\n|\r', '');

			List<String> vListAllSkills = new List<String>();
			String vSkill = (inputValues[1] +'_' +
							inputValues[2]).replaceAll('\r\n|\n|\r', '');
			vListAllSkills.add(vSkill);

			for (String vSkillKey : vListAllSkills) {
				String vSkillId = vMapSkillNameToId.containsKey(vSkillKey)
									? vMapSkillNameToId.get(vSkillKey)
									: null;
				String vSerResId = vMapServiceResourceToUserName.containsKey(firstCol)
									? vMapServiceResourceToUserName.get(firstCol)
									: null;
				String deDupKey = vSkillId + vSerResId;
				if (!vSetDeDup.contains(deDupKey)) {
					ServiceResourceSkill vSrSkill = new ServiceResourceSkill();
					vSrSkill.SkillId = vSkillId;
					vSrSkill.ServiceResourceId = vSerResId;
					vSrSkill.EffectiveStartDate = Datetime.valueOf(Datetime.valueOfGmt(((inputValues[3]).replaceAll('\r\n|\n|\r', '')).replace('T',' ')).format('yyyy-MM-dd\'T\'HH:mm:ssZ','America/Los_Angeles').replace('T',' '));
					vSrSkill.EffectiveEndDate = System.today().addDays(90);

					if (vSrSkill.SkillId == null || vSrSkill.ServiceResourceId == null) {
						vListMissingInfo.add(vSrSkill);
					} else {
						vListServiceResourceSkill.add(vSrSkill);
					}

					vSetDeDup.add(deDupKey);
				}
			}
		}

		vMapSkillNameToId.clear();

	    Database.SaveResult[] SR = Database.insert(vListServiceResourceSkill, false);
		if (errorCsvHeader == '') {
			errorCsvHeader = 'SkillId, ServiceResourceId, EffectiveStartDate, EffectiveEndDate, ErrorMessage \n';
			errorCsvBody += errorCsvHeader;
			errorSsvName = 'ServiceResourceSkill.csv';
		}
		for (Integer i = 0; i < SR.size(); i++) {
			if (!SR[i].isSuccess() && checkHeapLimit()) {
				//only look at failures, or NOT Successes
				errorEmailBody = 'Service Resource Skill insert error! Please validate attached data and load again!';
				errorCsvBody += vListServiceResourceSkill[i].SkillId + ', ' +
				                vListServiceResourceSkill[i].ServiceResourceId +', ' +
				                vListServiceResourceSkill[i].EffectiveStartDate +', ' +
				                vListServiceResourceSkill[i].EffectiveEndDate +', "' +
				                SR[i].getErrors() +'"\n';
			}
		}
		SR.clear();
		vListServiceResourceSkill.clear();
		if (!vListMissingInfo.isEmpty()) {
			for (ServiceResourceSkill vTemp : vListMissingInfo) {
				if (checkHeapLimit()) {
				  errorEmailBody = 'Service Resource Skill insert error! Please validate attached data and load again!';
				  errorCsvBody += vTemp.SkillId +', ' +
				                  vTemp.ServiceResourceId +', ' +
				                  vTemp.EffectiveStartDate +', ' +
				                  vTemp.EffectiveEndDate +', ' +
				                  ', Missing required info \n';
				}
			}
		}
  	}

  	public void addServiceTerritoryMember(List<String> filelines) {
		Set<String> vSetStringUserNames = new Set<String>();
		Set<String> vSetStringTerrNames = new Set<String>();
		Set<String> vSetStringOHNames = new Set<String>();

		for (Integer i = 0; i < filelines.size(); i++) {
			String[] inputvalues = filelines[i].split(',');
			vSetStringUserNames.add((inputValues[0]).replaceAll('\r\n|\n|\r', ''));
			vSetStringTerrNames.add((inputValues[1]).replaceAll('\r\n|\n|\r', ''));
			vSetStringOHNames.add((inputValues[3]).replaceAll('\r\n|\n|\r', ''));
		}

		Map<String, Id> vMapServiceResourceToUserName = new Map<String, Id>();
		Map<String, Id> vMapSerTerNameToId = new Map<String, Id>();
		Map<String, Id> vMapSerOHNameToId = new Map<String, Id>();

		//First fetch all existing data to map to CSV column values.
		if (!vSetStringUserNames.isEmpty()) {
			for (ServiceResource vServiceResource : [SELECT Id, Name, RelatedRecord.UserName
													   FROM ServiceResource
													  WHERE RelatedRecord.UserName IN :vSetStringUserNames
			]) {
				vMapServiceResourceToUserName.put(vServiceResource.RelatedRecord.UserName, vServiceResource.Id);
			}
		}
		vSetStringUserNames.clear();
		for (ServiceTerritory vSerTer : [SELECT Id, Name
										   FROM ServiceTerritory
										  WHERE Name IN :vSetStringTerrNames
		]) {
			vMapSerTerNameToId.put(vSerTer.Name, vSerTer.Id);
		}
		vSetStringTerrNames.clear();
		for(OperatingHours vOHNames: [SELECT Id, Name
										FROM OperatingHours
									   WHERE Name IN: vSetStringOHNames]){
			vMapSerOHNameToId.put(vOHNames.Name, vOHNames.Id);
		}
		vSetStringOHNames.clear();

		List<ServiceTerritoryMember> vListServiceTerrMember = new List<ServiceTerritoryMember>();
		List<ServiceTerritoryMember> vListMissingInfo = new List<ServiceTerritoryMember>();

		Set<String> vSetDeDup = new Set<String>();
		for (Integer i = 0; i < filelines.size(); i++) {
			String[] inputvalues = filelines[i].split(',');
			String firstCol = (inputValues[0]).replaceAll('\r\n|\n|\r', '');
			String vTerrName = (inputValues[1]).replaceAll('\r\n|\n|\r', '');
			String vOHName = (inputValues[3]).replaceAll('\r\n|\n|\r', '');

			String vServiceResourceId = (vMapServiceResourceToUserName.containsKey(firstCol))
										? '' + vMapServiceResourceToUserName.get(firstCol)
										: null;
			String vServiceTerrId = (vMapSerTerNameToId.containsKey(vTerrName))
									? '' + vMapSerTerNameToId.get(vTerrName)
									: null;
			String vOperatingHourId = (vMapSerOHNameToId.containsKey(vOHName))
										? '' + vMapSerOHNameToId.get(vOHName)
										: null;

			String deDupKey = vTerrName + vServiceResourceId + vServiceTerrId;
			if (!vSetDeDup.contains(deDupKey)) {
				ServiceTerritoryMember vSerTer = new ServiceTerritoryMember();
				vSerTer.ServiceResourceId = vServiceResourceId;
				vSerTer.ServiceTerritoryId = vServiceTerrId;
				vSerTer.OperatingHoursId = vOperatingHourId;
				vSerTer.EffectiveStartDate = Datetime.valueOf(Datetime.valueOfGmt(((inputValues[2]).replaceAll('\r\n|\n|\r', '')).replace('T',' ')).format('yyyy-MM-dd\'T\'HH:mm:ssZ','America/Los_Angeles').replace('T',' '));
				vSerTer.TerritoryType = (inputValues[4]).replaceAll('\r\n|\n|\r', '');

				//If there are no required fields, we will skip insertion of those records.
				if (vSerTer.ServiceResourceId == null || vSerTer.ServiceTerritoryId == null) {
		        	vListMissingInfo.add(vSerTer);
		        } else {
					vListServiceTerrMember.add(vSerTer);
				}
			}
			vSetDeDup.add(deDupKey);
		}

		Database.SaveResult[] SR = Database.insert(vListServiceTerrMember, false);

		//All below logic is to prepare a CSV with all failed records. This will help admins to mitigate errors.
		if (errorCsvHeader == '') {
			errorCsvHeader = 'ServiceResourceId, ServiceTerritoryId, EffectiveStartDate, OperatingHoursId, TerritoryType, ErrorMessage \n';
			errorCsvBody += errorCsvHeader;
			errorSsvName = 'ServiceTerritoryMember.csv';
		}
		for (Integer i = 0; i < SR.size(); i++) {
			if (!SR[i].isSuccess() && checkHeapLimit()) {
				//only look at failures, or NOT Successes
				errorEmailBody = 'Service Territory Member insert error! Please validate attached data and load again!';
				errorCsvBody += vListServiceTerrMember[i].ServiceResourceId +', ' +
								vListServiceTerrMember[i].ServiceTerritoryId +', ' +
								vListServiceTerrMember[i].EffectiveStartDate +', ' +
								vListServiceTerrMember[i].OperatingHoursId +', ' +
								vListServiceTerrMember[i].TerritoryType +',"' +
								SR[i].getErrors() +'"\n';
			}
		}
		SR.clear();
		vListServiceTerrMember.clear();
		if (!vListMissingInfo.isEmpty()) {
			for (ServiceTerritoryMember vTemp : vListMissingInfo) {
				if (checkHeapLimit()) {
					errorEmailBody = 'Service Territory Member insert error! Please validate attached data and load again!';
					errorCsvBody += vTemp.ServiceResourceId +', ' +
									vTemp.ServiceTerritoryId +', ' +
									vTemp.EffectiveStartDate +', ' +
									vTemp.OperatingHoursId +', ' +
									vTemp.TerritoryType +
									', Missing required info \n';
				}
			}
		}
  	}

  	//Just to validate if we are not reaching heap limits while performing all operations.
  	//Since heap calculation in APEX happens near real time during transaction, adding
  	//a buffer of 100
  	public boolean checkHeapLimit() {
    	return (Limits.getHeapSize() + 100 < Limits.getLimitHeapSize());
  	}

}
