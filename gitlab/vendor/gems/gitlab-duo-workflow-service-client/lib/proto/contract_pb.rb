# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: contract.proto

require 'google/protobuf'


descriptor_data = "\n\x0e\x63ontract.proto\"s\n\x0b\x43lientEvent\x12-\n\x0cstartRequest\x18\x01 \x01(\x0b\x32\x15.StartWorkflowRequestH\x00\x12)\n\x0e\x61\x63tionResponse\x18\x02 \x01(\x0b\x32\x0f.ActionResponseH\x00\x42\n\n\x08response\"k\n\x14StartWorkflowRequest\x12\x15\n\rclientVersion\x18\x01 \x01(\t\x12\x12\n\nworkflowID\x18\x02 \x01(\t\x12\x1a\n\x12workflowDefinition\x18\x03 \x01(\t\x12\x0c\n\x04goal\x18\x04 \x01(\t\"5\n\x0e\x41\x63tionResponse\x12\x11\n\trequestID\x18\x01 \x01(\t\x12\x10\n\x08response\x18\x02 \x01(\t\"\xbf\x01\n\x06\x41\x63tion\x12\x11\n\trequestID\x18\x01 \x01(\t\x12\'\n\nrunCommand\x18\x02 \x01(\x0b\x32\x11.RunCommandActionH\x00\x12)\n\x0erunHTTPRequest\x18\x03 \x01(\x0b\x32\x0f.RunHTTPRequestH\x00\x12 \n\x0brunReadFile\x18\x04 \x01(\x0b\x32\t.ReadFileH\x00\x12\"\n\x0crunWriteFile\x18\x05 \x01(\x0b\x32\n.WriteFileH\x00\x42\x08\n\x06\x61\x63tion\"#\n\x10RunCommandAction\x12\x0f\n\x07\x63ommand\x18\x01 \x01(\t\"\x1c\n\x08ReadFile\x12\x10\n\x08\x66ilepath\x18\x01 \x01(\t\"/\n\tWriteFile\x12\x10\n\x08\x66ilepath\x18\x01 \x01(\t\x12\x10\n\x08\x63ontents\x18\x02 \x01(\t\"J\n\x0eRunHTTPRequest\x12\x0e\n\x06method\x18\x01 \x01(\t\x12\x0c\n\x04path\x18\x02 \x01(\t\x12\x11\n\x04\x62ody\x18\x03 \x01(\tH\x00\x88\x01\x01\x42\x07\n\x05_body\"\x16\n\x14GenerateTokenRequest\"9\n\x15GenerateTokenResponse\x12\r\n\x05token\x18\x01 \x01(\t\x12\x11\n\texpiresAt\x18\x02 \x01(\x03\x32{\n\x0b\x44uoWorkflow\x12,\n\x0f\x45xecuteWorkflow\x12\x0c.ClientEvent\x1a\x07.Action(\x01\x30\x01\x12>\n\rGenerateToken\x12\x15.GenerateTokenRequest\x1a\x16.GenerateTokenResponseBfZOgitlab.com/gitlab-org/ai-powered/ai-framework/duo_workflow_executor/pkg/service\xea\x02\x12\x44uoWorkflowServiceb\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module DuoWorkflowService
  ClientEvent = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("ClientEvent").msgclass
  StartWorkflowRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("StartWorkflowRequest").msgclass
  ActionResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("ActionResponse").msgclass
  Action = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("Action").msgclass
  RunCommandAction = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("RunCommandAction").msgclass
  ReadFile = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("ReadFile").msgclass
  WriteFile = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("WriteFile").msgclass
  RunHTTPRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("RunHTTPRequest").msgclass
  GenerateTokenRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("GenerateTokenRequest").msgclass
  GenerateTokenResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("GenerateTokenResponse").msgclass
end
