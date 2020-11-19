require_relative '../lib/querylet'
require 'pry'

describe Querylet::Querylet do
  let(:querylet) {Querylet::Querylet.new path: File.expand_path('./') }

  def evaluate(template, data = {})
    querylet.compile(template).call(data)
  end

  context 'evaluating' do
    it 'a dummy template' do
      expect(evaluate('My simple template')).to eq('My simple template')
    end

    it 'a simple replacement' do
      expect(evaluate('Hello {{name}}', {name: 'world'})).to eq('Hello world')
    end

    it 'a double braces replacement with nil' do
      expect(evaluate('Hello {{name}}', {name: nil})).to eq('Hello ')
    end

    context 'helpers' do
      it 'include' do
query = <<-SQL.chomp
(SELECT
  users.email
FROM users
WHERE
  users.id = 1) as email
SQL
        expect(evaluate("({{> include 'examples.include' }}) as email")).to eq(query)
      end

      it 'include with variables' do
query = <<-SQL.chomp
(SELECT
  users.email
FROM users
WHERE
  users.id = 100) as email
SQL
        template = "({{> include 'examples.include_with_vars' }}) as email"
        expect(evaluate(template, {id: 100})).to eq(query)
      end

      it 'include with parameters' do
query = <<-SQL.chomp
(SELECT
  users.email,
  'andrew' as name
FROM users
WHERE
  users.id = 100) as email
SQL
        template = "({{> include 'examples.include_with_params' name='andrew' }}) as email"
        expect(evaluate(template, {id: 100})).to eq(query)
      end

    end # context 'helpers'
  end # context 'evaluating'
end