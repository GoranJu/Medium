import { duoChatGlobalState } from '~/super_sidebar/constants';

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * Sends a command to DuoChat to execute on. This should be use for
 * a single command.
 *
 * @param {question} String - Prompt to send to the chat endpoint
 * @param {resourceId} String - Unique ID to bind the streaming
 * @param {variables} Object - Additional variables to pass to graphql chat mutation
 */
export const sendDuoChatCommand = ({ question, resourceId, variables = {} } = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }
  if (!duoChatGlobalState.isShown) {
    duoChatGlobalState.isShown = true;
  }

  duoChatGlobalState.commands.push({ question, resourceId, variables });
};

export const clearDuoChatCommands = () => {
  duoChatGlobalState.commands = [];
};

export const utils = {
  concatStreamedChunks,
};
