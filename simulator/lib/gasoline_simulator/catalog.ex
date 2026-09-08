defmodule GasolineSimulator.Catalog do
  @refineries %{
    "REPLAN" => {"Refinaria de Paulínia", "SP", []},
    "REFMAT" => {"Refinaria de Mataripe", "BA", ["RLAM", "CEBV"]},
    "REVAP" => {"Refinaria Henrique Lage", "SP", []},
    "REDUC" => {"Refinaria Duque de Caxias", "RJ", []},
    "REPAR" => {"Refinaria Presidente Getúlio Vargas", "PR", []},
    "REFAP" => {"Refinaria Alberto Pasqualini", "RS", []},
    "RPBC" => {"Refinaria Presidente Bernardes", "SP", []},
    "REGAP" => {"Refinaria Gabriel Passos", "MG", []},
    "RECAP" => {"Refinaria de Capuava", "SP", []},
    "REAM" => {"Refinaria de Manaus", "AM", ["REMAN"]},
    "RPCC" => {"Refinaria Clara Camarão", "RN", []},
    "RNEST" => {"Refinaria Abreu e Lima", "PE", []},
    "LUBNOR" => {"Lubrificantes e Derivados de Petróleo do Nordeste", "CE", []}
  }

  @spec all() :: [map()]
  def all do
    Enum.map(@refineries, fn {id, {name, uf, aliases}} ->
      %{id: id, name: name, uf: uf, aliases: aliases}
    end)
  end

  @spec ids() :: [String.t()]
  def ids, do: Map.keys(@refineries)

  @spec find(String.t()) :: map() | nil
  def find(id_or_alias) do
    Enum.find(all(), &(id_or_alias == &1.id or id_or_alias in &1.aliases))
  end

  @spec canonical_id(String.t()) :: String.t() | nil
  def canonical_id(id_or_alias) do
    case find(id_or_alias) do
      nil -> nil
      refinery -> refinery.id
    end
  end
end
