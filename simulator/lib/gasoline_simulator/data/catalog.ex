defmodule GasolineSimulator.Data.Catalog do
  @refineries %{
    "REPLAN" => {"Refinaria de Paulínia", "SP"},
    "REFMAT" => {"Refinaria de Mataripe", "BA"},
    "REVAP" => {"Refinaria Henrique Lage", "SP"},
    "REDUC" => {"Refinaria Duque de Caxias", "RJ"},
    "REPAR" => {"Refinaria Presidente Getúlio Vargas", "PR"},
    "REFAP" => {"Refinaria Alberto Pasqualini", "RS"},
    "RPBC" => {"Refinaria Presidente Bernardes", "SP"},
    "REGAP" => {"Refinaria Gabriel Passos", "MG"},
    "RECAP" => {"Refinaria de Capuava", "SP"},
    "REAM" => {"Refinaria de Manaus", "AM"},
    "RPCC" => {"Refinaria Clara Camarão", "RN"},
    "RNEST" => {"Refinaria Abreu e Lima", "PE"},
    "LUBNOR" => {"Lubrificantes e Derivados de Petróleo do Nordeste", "CE"}
  }

  @spec find(String.t()) :: map() | nil
  def find(id) do
    case Map.get(@refineries, id) do
      {name, uf} -> %{id: id, name: name, uf: uf}
      nil -> nil
    end
  end
end
