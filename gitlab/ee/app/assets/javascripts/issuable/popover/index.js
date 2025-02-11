import initIssuablePopoverCE, {
  handleIssuablePopoverMount as handleIssuablePopoverMountCE,
  componentsByReferenceTypeMap as componentsByReferenceTypeMapCE,
} from '~/issuable/popover';

import EpicPopover from './components/epic_popover.vue';

const componentsByReferenceTypeMap = {
  ...componentsByReferenceTypeMapCE,
  epic: EpicPopover,
};

export const handleIssuablePopoverMount = ({
  componentsByReferenceType = componentsByReferenceTypeMap,
  apolloProvider,
  namespacePath,
  title,
  iid,
  milestone,
  innerText,
  referenceType,
  target,
  placement,
}) =>
  handleIssuablePopoverMountCE({
    componentsByReferenceType,
    apolloProvider,
    namespacePath,
    title,
    iid,
    milestone,
    innerText,
    referenceType,
    target,
    placement,
  });

export default (elements, issuablePopoverMount = handleIssuablePopoverMount) =>
  initIssuablePopoverCE(elements, issuablePopoverMount);
