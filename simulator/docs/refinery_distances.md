# Distâncias entre refinarias

Este arquivo registra a distância de cada par e o tempo de um caminhão a 60 km/h. A volta usa os mesmos números. Ele é documentação. A simulação não lê este arquivo. Os quilômetros de rodovia que ela usa estão em `Refineries.Distances`.

A tabela foi preenchida com a saída do script desta página. A linha reta vem de `great_circle_km`. A rodovia vem de `road_km`. As horas vêm de `truck_hours`. Os dias são essas horas divididas por 24.

## Pontos

A coordenada vem da Wikipédia quando a página publica o ponto da refinaria. REAM, RECAP e RPCC não têm coordenada nessa fonte. Nesses três casos o ponto é o da instalação no OpenStreetMap, obtido pelo Nominatim.

| Código | Nome | UF | Latitude | Longitude | Fonte |
|---|---|---|---:|---:|---|
| REAM | Refinaria Isaac Sabbá | AM | -3.14683 | -59.95362 | [OpenStreetMap](https://www.openstreetmap.org/?mlat=-3.1468257&mlon=-59.9536165) |
| RECAP | Refinaria de Capuava | SP | -23.65388 | -46.48101 | [OpenStreetMap](https://www.openstreetmap.org/?mlat=-23.6538826&mlon=-46.4810068) |
| REDUC | Refinaria Duque de Caxias | RJ | -22.71817 | -43.27062 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_de_Duque_de_Caxias) |
| REFAP | Refinaria Alberto Pasqualini | RS | -29.87247 | -51.16099 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_Alberto_Pasqualini) |
| REFMAT | Refinaria de Mataripe | BA | -12.70524 | -38.56667 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_de_Mataripe) |
| REGAP | Refinaria Gabriel Passos | MG | -19.97313 | -44.09617 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_Gabriel_Passos) |
| REPAR | Refinaria Presidente Getúlio Vargas | PR | -25.56827 | -49.36429 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_Presidente_Getúlio_Vargas) |
| REPLAN | Refinaria de Paulínia | SP | -22.72833 | -47.13167 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_de_Paulínia) |
| REVAP | Refinaria Henrique Lage | SP | -23.19167 | -45.82722 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_Henrique_Lage) |
| RNEST | Refinaria Abreu e Lima | PE | -8.39861 | -35.06750 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_Abreu_e_Lima) |
| RPBC | Refinaria Presidente Bernardes | SP | -23.86969 | -46.43309 | [Wikipédia](https://pt.wikipedia.org/wiki/Refinaria_Presidente_Bernardes) |
| RPCC | Refinaria Clara Camarão | RN | -5.13257 | -36.38461 | [OpenStreetMap](https://www.openstreetmap.org/?mlat=-5.1325723&mlon=-36.3846133) |

## Conta

A linha reta é a distância de grande círculo entre os dois pontos, com raio da Terra de 6371 km.

A rodovia é a rota de carro do OSRM sobre o OpenStreetMap, a mesma chamada de `road_km`. A consulta sai do código que vem antes no alfabeto e chega no outro. A distância de volta fica igual nesta tabela. A tabela abaixo é o retorno dessa chamada em 11 de outubro de 2026.

O tempo é a distância rodoviária dividida por 60. O caminhão segue sem parada de descanso. Os números usam ponto como separador decimal.

Vários trechos curtos, sobretudo entre as plantas de São Paulo, levam menos de um dia.

A saída da REAM segue a malha rodoviária mapeada. A rodovia fica bem mais longa que a linha reta porque o caminho contorna a floresta. Na operação real, produto saindo de Manaus costuma seguir de navio ou balsa. A tabela ainda mostra o caminhão, que é a conta pedida.

## Script de conferência

A tabela de pontos arredonda a coordenada em cinco casas. O script abaixo usa o valor completo que gerou os quilômetros. Copie o bloco e rode com `python3`.

Ao rodar, o script imprime uma linha de tabela por par. `road_km` pede a rota ao OSRM. Uma consulta nova pode divergir se o mapa mudou depois de 11 de outubro de 2026.

```python
import json
import math
import urllib.request

EARTH_RADIUS_KM = 6371.0
TRUCK_SPEED_KM_H = 60.0

PLANTS = {
    "REAM": (-3.1468257, -59.9536165),
    "RECAP": (-23.6538826, -46.4810068),
    "REDUC": (-22.71816944, -43.27061944),
    "REFAP": (-29.87247222, -51.16099167),
    "REFMAT": (-12.70524444, -38.56666944),
    "REGAP": (-19.97313333, -44.09616667),
    "REPAR": (-25.568275, -49.36428611),
    "REPLAN": (-22.72833333, -47.13166667),
    "REVAP": (-23.191667, -45.827222),
    "RNEST": (-8.39861, -35.0675),
    "RPBC": (-23.86969444, -46.43308889),
    "RPCC": (-5.1325723, -36.3846133),
}


def great_circle_km(origin, destination):
    lat1, lon1 = (math.radians(value) for value in PLANTS[origin])
    lat2, lon2 = (math.radians(value) for value in PLANTS[destination])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(h))


def truck_hours(road_km):
    return road_km / TRUCK_SPEED_KM_H


def road_km(origin, destination):
    lat1, lon1 = PLANTS[origin]
    lat2, lon2 = PLANTS[destination]
    url = (
        "https://router.project-osrm.org/route/v1/driving/"
        f"{lon1},{lat1};{lon2},{lat2}?overview=false"
    )
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "tcc-gasoline-simulator/1.0 (academic)"},
    )
    with urllib.request.urlopen(request, timeout=40) as response:
        payload = json.load(response)
    return payload["routes"][0]["distance"] / 1000.0


if __name__ == "__main__":
    codes = sorted(PLANTS)
    for left, origin in enumerate(codes):
        for destination in codes[left + 1 :]:
            straight = great_circle_km(origin, destination)
            road = road_km(origin, destination)
            hours = truck_hours(road)
            print(
                f"| {origin} → {destination} | {straight:.1f} | {road:.1f} | {hours:.1f} | {hours / 24:.2f} |"
            )
```

A tabela deste arquivo é essa impressão. As seções de exemplos e de todos os pares repetem a mesma saída.

## Exemplos

| Trecho | Linha reta (km) | Rodovia (km) | Horas a 60 km/h | Dias (horas / 24) |
|---|---:|---:|---:|---:|
| RPCC → RPBC | 2344.8 | 2971.4 | 49.5 | 2.06 |
| RNEST → RPCC | 391.2 | 495.4 | 8.3 | 0.34 |

## Todos os pares

| Trecho | Linha reta (km) | Rodovia (km) | Horas a 60 km/h | Dias (horas / 24) |
|---|---:|---:|---:|---:|
| REAM → RECAP | 2701.2 | 3876.3 | 64.6 | 2.69 |
| REAM → REDUC | 2822.5 | 4247.6 | 70.8 | 2.95 |
| REAM → REFAP | 3112.8 | 4425.8 | 73.8 | 3.07 |
| REAM → REFMAT | 2581.2 | 4586.1 | 76.4 | 3.18 |
| REAM → REGAP | 2541.6 | 3889.3 | 64.8 | 2.70 |
| REAM → REPAR | 2738.0 | 4008.9 | 66.8 | 2.78 |
| REAM → REPLAN | 2578.7 | 3750.6 | 62.5 | 2.60 |
| REAM → REVAP | 2697.9 | 3924.1 | 65.4 | 2.73 |
| REAM → RNEST | 2813.2 | 4676.6 | 77.9 | 3.25 |
| REAM → RPBC | 2723.7 | 3917.6 | 65.3 | 2.72 |
| REAM → RPCC | 2623.0 | 4524.5 | 75.4 | 3.14 |
| RECAP → REDUC | 344.2 | 444.3 | 7.4 | 0.31 |
| RECAP → REFAP | 832.8 | 1173.2 | 19.6 | 0.81 |
| RECAP → REFMAT | 1475.9 | 1937.1 | 32.3 | 1.35 |
| RECAP → REGAP | 477.6 | 577.4 | 9.6 | 0.40 |
| RECAP → REPAR | 360.9 | 470.0 | 7.8 | 0.33 |
| RECAP → REPLAN | 122.5 | 150.2 | 2.5 | 0.10 |
| RECAP → REVAP | 84.2 | 117.1 | 2.0 | 0.08 |
| RECAP → RNEST | 2086.6 | 2616.0 | 43.6 | 1.82 |
| RECAP → RPBC | 24.5 | 54.4 | 0.9 | 0.04 |
| RECAP → RPCC | 2326.2 | 2930.1 | 48.8 | 2.03 |
| REDUC → REFAP | 1118.0 | 1560.5 | 26.0 | 1.08 |
| REDUC → REFMAT | 1219.4 | 1553.3 | 25.9 | 1.08 |
| REDUC → REGAP | 317.0 | 420.3 | 7.0 | 0.29 |
| REDUC → REPAR | 694.7 | 857.3 | 14.3 | 0.60 |
| REDUC → REPLAN | 396.0 | 505.1 | 8.4 | 0.35 |
| REDUC → REVAP | 267.0 | 328.3 | 5.5 | 0.23 |
| REDUC → RNEST | 1817.2 | 2232.2 | 37.2 | 1.55 |
| REDUC → RPBC | 347.4 | 477.8 | 8.0 | 0.33 |
| REDUC → RPCC | 2090.7 | 2546.3 | 42.4 | 1.77 |
| REFAP → REFMAT | 2308.0 | 3042.9 | 50.7 | 2.11 |
| REFAP → REGAP | 1310.3 | 1683.2 | 28.1 | 1.17 |
| REFAP → REPAR | 510.2 | 740.2 | 12.3 | 0.51 |
| REFAP → REPLAN | 890.0 | 1230.1 | 20.5 | 0.85 |
| REFAP → REVAP | 912.6 | 1232.9 | 20.5 | 0.86 |
| REFAP → RNEST | 2917.5 | 3721.8 | 62.0 | 2.58 |
| REFAP → RPBC | 815.5 | 1117.6 | 18.6 | 0.78 |
| REFAP → RPCC | 3157.9 | 4036.0 | 67.3 | 2.80 |
| REFMAT → REGAP | 1000.3 | 1367.2 | 22.8 | 0.95 |
| REFMAT → REPAR | 1823.3 | 2465.1 | 41.1 | 1.71 |
| REFMAT → REPLAN | 1436.1 | 1975.6 | 32.9 | 1.37 |
| REFMAT → REVAP | 1395.5 | 1886.4 | 31.4 | 1.31 |
| REFMAT → RNEST | 612.8 | 761.3 | 12.7 | 0.53 |
| REFMAT → RPBC | 1492.6 | 1979.6 | 33.0 | 1.37 |
| REFMAT → RPCC | 875.4 | 1135.2 | 18.9 | 0.79 |
| REGAP → REPAR | 823.7 | 986.5 | 16.4 | 0.69 |
| REGAP → REPLAN | 438.9 | 584.9 | 9.7 | 0.41 |
| REGAP → REVAP | 400.1 | 526.1 | 8.8 | 0.37 |
| REGAP → RNEST | 1612.4 | 2044.5 | 34.1 | 1.42 |
| REGAP → RPBC | 495.8 | 619.3 | 10.3 | 0.43 |
| REGAP → RPCC | 1849.1 | 2358.7 | 39.3 | 1.64 |
| REPAR → REPLAN | 388.6 | 533.2 | 8.9 | 0.37 |
| REPAR → REVAP | 445.1 | 536.0 | 8.9 | 0.37 |
| REPAR → RNEST | 2435.8 | 3145.5 | 52.4 | 2.18 |
| REPAR → RPBC | 351.2 | 420.7 | 7.0 | 0.29 |
| REPAR → RPCC | 2659.8 | 3459.6 | 57.7 | 2.40 |
| REPLAN → REVAP | 143.1 | 190.2 | 3.2 | 0.13 |
| REPLAN → RNEST | 2048.8 | 2663.7 | 44.4 | 1.85 |
| REPLAN → RPBC | 145.6 | 194.8 | 3.2 | 0.14 |
| REPLAN → RPCC | 2271.7 | 2977.8 | 49.6 | 2.07 |
| REVAP → RNEST | 2005.4 | 2563.7 | 42.7 | 1.78 |
| REVAP → RPBC | 97.5 | 154.8 | 2.6 | 0.11 |
| REVAP → RPCC | 2249.1 | 2877.8 | 48.0 | 2.00 |
| RNEST → RPBC | 2102.8 | 2658.1 | 44.3 | 1.85 |
| RNEST → RPCC | 391.2 | 495.4 | 8.3 | 0.34 |
| RPBC → RPCC | 2344.8 | 2971.4 | 49.5 | 2.06 |

## Fontes

- Coordenadas com página própria: Wikipédia em português, propriedade de coordenada de cada artigo ligado na tabela de pontos.
- REAM, RECAP e RPCC: Nominatim, OpenStreetMap, objetos industriais Refinaria Isaac Sabbá, Refinaria Capuava e Refinaria Potiguar Clara Camarão.
- Rotas: OSRM, perfil `driving`, `https://router.project-osrm.org/`.
