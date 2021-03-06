all:
	sh scripts/download_dependencies.sh
	python scripts/build_frameworks.py
	python scripts/generate_xcconfigs.py
	$(MAKE) -C MockUtils prepare
	$(MAKE) -C Core/StitchCoreSDK prepare
	$(MAKE) -C Core/StitchCoreAdminClient prepare
	$(MAKE) -C Core/StitchCoreTestUtils prepare
	$(MAKE) -C Core/Services/StitchCoreAWSService prepare
	$(MAKE) -C Core/Services/StitchCoreFCMService prepare
	$(MAKE) -C Core/Services/StitchCoreHTTPService prepare
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService prepare
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService prepare
	$(MAKE) -C Core/Services/StitchCoreTwilioService prepare
clean:
	rm -rf ./vendor
	rm -rf ./.build
	rm -rf dist
	rm -rf Frameworks
	$(MAKE) -C MockUtils clean
	$(MAKE) -C Core/StitchCoreSDK clean
	$(MAKE) -C Core/StitchCoreAdminClient clean
	$(MAKE) -C Core/StitchCoreTestUtils clean
	$(MAKE) -C Core/Services/StitchCoreAWSService clean
	$(MAKE) -C Core/Services/StitchCoreFCMService clean
	$(MAKE) -C Core/Services/StitchCoreHTTPService clean
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService clean
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService clean
	$(MAKE) -C Core/Services/StitchCoreTwilioService clean	
lint:
	$(MAKE) -C MockUtils lint
	$(MAKE) -C Core/StitchCoreSDK lint
	$(MAKE) -C Core/StitchCoreAdminClient lint
	$(MAKE) -C Core/StitchCoreTestUtils lint
	$(MAKE) -C Core/Services/StitchCoreAWSService lint
	$(MAKE) -C Core/Services/StitchCoreAWSS3Service lint
	$(MAKE) -C Core/Services/StitchCoreAWSSESService lint
	$(MAKE) -C Core/Services/StitchCoreFCMService lint
	$(MAKE) -C Core/Services/StitchCoreHTTPService lint
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService lint
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService lint
	$(MAKE) -C Core/Services/StitchCoreTwilioService lint
git:
	$(MAKE) -C MockUtils git
	$(MAKE) -C Core/StitchCoreSDK git
	$(MAKE) -C Core/StitchCoreAdminClient git
	$(MAKE) -C Core/StitchCoreTestUtils git
	$(MAKE) -C Core/Services/StitchCoreAWSService git
	$(MAKE) -C Core/Services/StitchCoreAWSS3Service git
	$(MAKE) -C Core/Services/StitchCoreAWSSESService git
	$(MAKE) -C Core/Services/StitchCoreFCMService git
	$(MAKE) -C Core/Services/StitchCoreHTTPService git
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService git
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService git
	$(MAKE) -C Core/Services/StitchCoreTwilioService git
update:
	$(MAKE) -C MockUtils update
	$(MAKE) -C Core/StitchCoreSDK update
	$(MAKE) -C Core/StitchCoreAdminClient update
	$(MAKE) -C Core/StitchCoreTestUtils update
	$(MAKE) -C Core/Services/StitchCoreAWSService update
	$(MAKE) -C Core/Services/StitchCoreAWSS3Service update
	$(MAKE) -C Core/Services/StitchCoreAWSSESService update
	$(MAKE) -C Core/Services/StitchCoreFCMService update
	$(MAKE) -C Core/Services/StitchCoreHTTPService update
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService update
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService update
	$(MAKE) -C Core/Services/StitchCoreTwilioService update
test:
	$(MAKE) -C MockUtils test
	$(MAKE) -C Core/StitchCoreSDK test
	$(MAKE) -C Core/StitchCoreAdminClient test
	$(MAKE) -C Core/StitchCoreTestUtils test
	$(MAKE) -C Core/Services/StitchCoreAWSService test
	$(MAKE) -C Core/Services/StitchCoreAWSS3Service test
	$(MAKE) -C Core/Services/StitchCoreAWSSESService test
	$(MAKE) -C Core/Services/StitchCoreFCMService test
	$(MAKE) -C Core/Services/StitchCoreHTTPService test
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService test
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService test
	$(MAKE) -C Core/Services/StitchCoreTwilioService test
project:
	$(MAKE) -C MockUtils project
	$(MAKE) -C Core/StitchCoreSDK project
	$(MAKE) -C Core/StitchCoreAdminClient project
	$(MAKE)	-C Core/StitchCoreTestUtils project
	$(MAKE) -C Core/Services/StitchCoreAWSService project
	$(MAKE) -C Core/Services/StitchCoreAWSS3Service project
	$(MAKE) -C Core/Services/StitchCoreAWSSESService project
	$(MAKE) -C Core/Services/StitchCoreFCMService project
	$(MAKE) -C Core/Services/StitchCoreHTTPService project
	$(MAKE) -C Core/Services/StitchCoreLocalMongoDBService project
	$(MAKE) -C Core/Services/StitchCoreRemoteMongoDBService project
	$(MAKE) -C Core/Services/StitchCoreTwilioService project
