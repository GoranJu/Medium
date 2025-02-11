import {
  ISSUABLE_CHANGE_LABEL,
  ISSUABLE_COMMENT_OR_REPLY,
  ISSUABLE_EDIT_DESCRIPTION,
} from '~/behaviors/shortcuts/keybindings';
import ShortcutsIssuable from '~/behaviors/shortcuts/shortcuts_issuable';

export default class ShortcutsEpic {
  constructor(shortcuts) {
    shortcuts.addAll([
      [ISSUABLE_CHANGE_LABEL, ShortcutsEpic.openSidebarDropdown],
      [ISSUABLE_COMMENT_OR_REPLY, ShortcutsIssuable.replyWithSelectedText],
      [ISSUABLE_EDIT_DESCRIPTION, ShortcutsIssuable.editIssue],
    ]);
  }

  static dependencies = [ShortcutsIssuable];

  static openSidebarDropdown() {
    document.dispatchEvent(new Event('toggleSidebarRevealLabelsDropdown'));
  }
}
