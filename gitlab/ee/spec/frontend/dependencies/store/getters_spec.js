import * as getters from 'ee/dependencies/store/getters';

describe('Dependencies getters', () => {
  describe.each`
    getterName         | propertyName
    ${'isInitialized'} | ${'initialized'}
  `('$getterName', ({ getterName, propertyName }) => {
    it(`returns the value from the current list module's state`, () => {
      const mockValue = {};
      const state = {
        listFoo: {
          [propertyName]: mockValue,
        },
        currentList: 'listFoo',
      };

      expect(getters[getterName](state)).toBe(mockValue);
    });
  });

  describe('totals', () => {
    it('returns a map of list module namespaces to total counts', () => {
      const state = {
        listTypes: [
          { namespace: 'foo' },
          { namespace: 'bar' },
          { namespace: 'qux' },
          { namespace: 'foobar' },
        ],
        foo: { pageInfo: { total: 1 } },
        bar: { pageInfo: { total: 2 } },
        qux: { pageInfo: { total: NaN } },
        foobar: { pageInfo: {} },
      };

      expect(getters.totals(state)).toEqual({
        foo: 1,
        bar: 2,
        qux: 0,
        foobar: 0,
      });
    });
  });
});
