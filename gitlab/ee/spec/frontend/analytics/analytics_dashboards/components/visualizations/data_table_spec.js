import { GlIcon, GlTableLite } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DataTable from 'ee/analytics/analytics_dashboards/components/visualizations/data_table.vue';

describe('DataTable Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAll('th');
  const findTableRowCells = (idx) => findTable().find('tbody').findAll('tr').at(idx).findAll('td');

  const data = [{ field_one: 'alpha', field_two: 'beta' }];

  const createWrapper = (mountFn = shallowMount, props = {}) => {
    wrapper = extendedWrapper(
      mountFn(DataTable, {
        propsData: {
          data,
          options: {},
          ...props,
        },
      }),
    );
  };

  describe('default behaviour', () => {
    it('should render the table with the expected attributes', () => {
      createWrapper();

      expect(findTable().attributes()).toMatchObject({
        responsive: '',
        hover: '',
      });
    });

    it('should render and style the table headers', () => {
      createWrapper(mount);

      const headers = findTableHeaders();

      expect(headers).toHaveLength(2);

      ['Field One', 'Field Two'].forEach((headerText, idx) => {
        expect(headers.at(idx).text()).toBe(headerText);
      });
    });

    it('should render and style the table cells', () => {
      createWrapper(mount);

      const rowCells = findTableRowCells(0);

      expect(rowCells).toHaveLength(2);

      Object.values(data[0]).forEach((value, idx) => {
        expect(rowCells.at(idx).text()).toBe(value);
        expect(rowCells.at(idx).classes()).toEqual(
          expect.arrayContaining(['gl-truncate', 'gl-max-w-0']),
        );
      });
    });

    it('should not add delimiters for small numbers', () => {
      createWrapper(mount, {
        data: [
          {
            field_one: 123,
          },
        ],
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe('123');
    });

    it.each([
      [1234, '1,234'],
      [12345, '12,345'],
      [123456789, '123,456,789'],
    ])('should format "%d" with delimiters as "%s"', (value, expected) => {
      createWrapper(mount, {
        data: [
          {
            field_one: value,
          },
        ],
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe(expected);
    });
  });

  describe('with links data', () => {
    it('should render values as links when provided with links data', () => {
      const linksData = [
        { foo: { text: 'foo', href: 'https://example.com/foo' } },
        { bar: { text: 'bar', href: 'https://example.com/bar' } },
      ];
      createWrapper(mount, { data: linksData });

      const rowCells = findTableRowCells(0);

      Object.values(linksData[0]).forEach((linkConfig, idx) => {
        const link = rowCells.at(idx).find('a');

        expect(link.exists()).toBe(true);
        expect(link.text()).toBe(linkConfig.text);
        expect(link.attributes('href')).toBe(linkConfig.href);
      });
    });

    it('should render external link icon for external links', () => {
      const linksData = [{ foo: { text: 'foo', href: 'https://example.com/foo' } }];
      createWrapper(mount, { data: linksData });

      const rowCells = findTableRowCells(0);

      Object.values(linksData[0]).forEach((linkConfig, idx) => {
        const icon = rowCells.at(idx).find('a').findComponent(GlIcon);

        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('external-link');
      });
    });

    it('should not add delimiters to link text for small numbers', () => {
      createWrapper(mount, {
        data: [{ foo: { text: 123, href: 'https://example.com/foo' } }],
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe('123');
    });

    it.each([
      [1234, '1,234'],
      [12345, '12,345'],
      [123456789, '123,456,789'],
    ])('should format link text of "%d" with delimiters as "%s"', (value, expected) => {
      createWrapper(mount, {
        data: [{ foo: { text: value, href: 'https://example.com/foo' } }],
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe(expected);
    });

    it('should not allow unsafe URLs to be linkable', () => {
      /* eslint-disable no-script-url */
      const linksData = [
        { foo: { text: 'foo', href: 'https://example.com/foo' } },
        { foo: { text: 'bar', href: 'javascript:alert("XSS")' } },
      ];
      /* eslint-enable no-script-url */

      createWrapper(mount, { data: linksData });

      const badLink = findTableRowCells(1).at(0).find('a');

      expect(findTableRowCells(0).at(0).find('a').exists()).toBe(true);
      expect(badLink.text()).toBe('bar');
      expect(badLink.attributes('href')).toBe('about:blank');
    });
  });
});
