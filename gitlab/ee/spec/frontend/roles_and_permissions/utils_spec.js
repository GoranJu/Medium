import { isCustomRole } from 'ee/roles_and_permissions/utils';
import { standardRoles, memberRoles } from './mock_data';

describe('Roles and permissions utils', () => {
  describe('isCustomRole', () => {
    describe.each(standardRoles)('for standard role $name', (role) => {
      it('returns false', () => {
        expect(isCustomRole(role)).toBe(false);
      });
    });

    describe.each(memberRoles)('for custom role $name', (role) => {
      it('returns true', () => {
        expect(isCustomRole(role)).toBe(true);
      });
    });
  });
});
