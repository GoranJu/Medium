export const mockSelfHostedModels = [
  {
    id: 1,
    name: 'Model 1',
    model: 'mistral',
    modelDisplayName: 'Mistral',
    releaseState: 'GA',
  },
  {
    id: 2,
    name: 'Model 2',
    model: 'codellama',
    modelDisplayName: 'Code Llama',
    releaseState: 'BETA',
  },
  {
    id: 3,
    name: 'Model 3',
    model: 'codegemma',
    modelDisplayName: 'CodeGemma',
    releaseState: 'BETA',
  },
  {
    id: 4,
    name: 'Model 4',
    model: 'gpt',
    modelDisplayName: 'GPT',
    releaseState: 'GA',
  },
  {
    id: 5,
    name: 'Model 5',
    model: 'claude_3',
    modelDisplayName: 'Claude 3',
    releaseState: 'GA',
  },
];

export const mockAiFeatureSettings = [
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    provider: 'vendored',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    provider: 'disabled',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'duo_chat',
    title: 'Duo Chat',
    mainFeature: 'Duo Chat',
    provider: 'self_hosted',
    selfHostedModel: {
      id: 2,
      name: 'Model 2',
      model: 'codellama',
      releaseState: 'BETA',
    },
    validModels: { nodes: mockSelfHostedModels },
  },
];
