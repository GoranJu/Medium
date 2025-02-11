# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Query, feature_category: :global_search do
  describe 'initialize' do
    it 'instance can read the query attribute' do
      expect(described_class.new('test').query).to eq 'test'
    end

    context 'when query is nil' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'query argument can not be nil')
      end
    end

    context 'when query is not passed' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new }.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end
    end
  end

  describe '#exact_search_query' do
    using RSpec::Parameterized::TableSyntax

    where(:query, :result) do
      ''                              | ''
      'test'                          | 'test'
      '^test.*\b\d+(a|b)[0-9]\sa{3}$' | %q(\^test\.\*\\\b\\\d\+\\(a\|b\\)\[0\-9\]\\\sa\{3\}\$)
      '"foo"'                         | %q(\"foo\")
      'lang:ruby    test'             | 'test lang:ruby'
      'case:no test'                  | 'test case:no'
      'foo:bar test'                  | 'foo\:bar\ test'
      'test    case:auto'             | 'test case:auto'
      'case:no test f:dummy.rb'       | 'test case:no f:dummy.rb'
      'case:no test -f:dummy.rb'      | 'test case:no -f:dummy.rb'
      'case:no file:dummy test'       | 'test case:no file:dummy'
      'case:no -file:dummy test'      | 'test case:no -file:dummy'
      'test case:no file:dummy'       | 'test case:no file:dummy'
      'test sym:foo'                  | 'test sym:foo'
      'sym:foo'                       | 'sym:foo'
    end

    with_them do
      it 'returns correct exact search query' do
        expect(described_class.new(query).exact_search_query).to eq result
      end
    end
  end
end
