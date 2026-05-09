# Skill: APIs Gratuitas para Projetos (Sem Autenticação)

Catálogo de APIs públicas e gratuitas que NÃO precisam de API key. Use para prototipar, testar e integrar em projetos.

## 🌤 Clima & Tempo
| API | URL | Descrição |
|-----|-----|-----------|
| Open-Meteo | `https://api.open-meteo.com/v1/forecast?latitude=-23.55&longitude=-46.63&daily=temperature_2m_max` | Previsão do tempo global, sem key |
| wttr.in | `https://wttr.in/SaoPaulo?format=3` | Clima em texto simples |
| 7Timer | `http://www.7timer.info/bin/api.pl?lon=-46.63&lat=-23.55&product=civil&output=json` | Previsão astronômica |

## 🖼 Imagens & Avatares
| API | URL | Descrição |
|-----|-----|-----------|
| Lorem Picsum | `https://picsum.photos/400/300` | Placeholder images aleatórias |
| DiceBear | `https://api.dicebear.com/6.x/pixel-art/svg` | Avatares SVG gerados |
| RoboHash | `https://robohash.org/meuusuario.png` | Imagens únicas a partir de texto |
| Dog CEO | `https://dog.ceo/api/breeds/image/random` | Fotos aleatórias de cachorros |
| RandomFox | `https://randomfox.ca/floof/` | Fotos de raposas |

## 😂 Diversão & Conteúdo
| API | URL | Descrição |
|-----|-----|-----------|
| JokeAPI | `https://v2.jokeapi.dev/joke/Any?safe-mode` | Piadas (safe mode) |
| Chuck Norris | `https://api.chucknorris.io/jokes/random` | Fatos do Chuck Norris |
| Dad Jokes | `https://icanhazdadjoke.com/` (header Accept: application/json) | Piadas de pai |
| Quotes | `https://api.quotable.io/quotes/random` | Citações aleatórias |
| Advice Slip | `https://api.adviceslip.com/advice` | Conselhos aleatórios |
| Open Trivia | `https://opentdb.com/api.php?amount=10&category=17` | Perguntas de trivia |

## 🎮 Games & Entretenimento
| API | URL | Descrição |
|-----|-----|-----------|
| PokéAPI | `https://pokeapi.co/api/v2/pokemon/pikachu` | Dados de Pokémon |
| Rick & Morty | `https://rickandmortyapi.com/api/character/1` | Personagens da série |
| SWAPI | `https://swapi.dev/api/people/1/?format=json` | Star Wars |
| D&D 5e | `https://www.dnd5eapi.co/api/classes` | Dungeons & Dragons |
| Deck of Cards | `https://deckofcardsapi.com/api/deck/new/shuffle/` | Simulador de baralho |
| FreeToGame | `https://www.freetogame.com/api/games?platform=pc` | Jogos gratuitos |

## 📚 Dados & Conhecimento
| API | URL | Descrição |
|-----|-----|-----------|
| Wikipedia | `https://en.wikipedia.org/w/api.php?action=query&prop=revisions&titles=React&rvprop=content&format=json` | Conteúdo da Wikipedia |
| Open Library | `https://openlibrary.org/search.json?q=javascript` | Busca de livros |
| Free Dictionary | `https://api.dictionaryapi.dev/api/v2/entries/en/programming` | Definições de palavras |
| Datamuse | `https://api.datamuse.com/words?ml=programming` | Palavras relacionadas |
| NASA | `https://api.nasa.gov/neo/rest/v1/neo/browse?api_key=DEMO_KEY` | Dados espaciais (DEMO_KEY) |

## 💰 Finanças & Crypto
| API | URL | Descrição |
|-----|-----|-----------|
| ExchangeRate | `https://open.er-api.com/v6/latest/USD` | Câmbio de moedas |
| CoinGecko | `https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd` | Preços de crypto |
| CoinPaprika | `https://api.coinpaprika.com/v1/coins/btc-bitcoin` | Dados de crypto |
| Binance | `https://api4.binance.com/api/v3/ticker/24hr` | Ticker 24h crypto |

## 🌍 Geo & Localização
| API | URL | Descrição |
|-----|-----|-----------|
| ViaCEP | `https://viacep.com.br/ws/01001000/json/` | CEP brasileiro |
| Nominatim | `https://nominatim.openstreetmap.org/search.php?city=saopaulo&format=jsonv2` | Geocoding |
| IPify | `https://api.ipify.org?format=json` | IP público |
| Zippopotamus | `https://api.zippopotam.us/us/90210` | Info por CEP (60 países) |
| Country.is | `https://api.country.is/8.8.8.8` | País por IP |

## 🧪 Dados de Teste
| API | URL | Descrição |
|-----|-----|-----------|
| JSONPlaceholder | `https://jsonplaceholder.typicode.com/posts/1` | REST API fake |
| RandomUser | `https://randomuser.me/api/` | Usuários fake |
| Faker | `https://fakerapi.it/api/v1/persons?_quantity=5` | Dados fake variados |
| Reqres | `https://reqres.in/api/users?page=1` | API de teste com paginação |

## 🍔 Comida & Bebida
| API | URL | Descrição |
|-----|-----|-----------|
| TheCocktailDB | `https://www.thecocktaildb.com/api/json/v1/1/search.php?s=margarita` | Receitas de drinks |
| Open Food Facts | `https://world.openfoodfacts.org/api/v0/product/737628064502.json` | Dados nutricionais |
| Open Brewery | `https://api.openbrewerydb.org/breweries` | Cervejarias |

## 🛠 Dev Tools
| API | URL | Descrição |
|-----|-----|-----------|
| HTTPBin | `http://httpbin.org/get` | Inspecionar headers/requests |
| QR Code | `http://api.qrserver.com/v1/create-qr-code/?data=hello&size=200x200` | Gerar QR codes |
| QuickChart | `https://quickchart.io/chart?c={type:'bar',data:{labels:['A','B'],datasets:[{data:[10,20]}]}}` | Gerar gráficos |

## 🏛 Dados Governamentais (BR)
| API | URL | Descrição |
|-----|-----|-----------|
| BrasilAPI | `https://brasilapi.com.br/api/feriados/v1/2026` | Feriados, CEP, CNPJ |
| Banco Central | `https://api.bcb.gov.br/dados/serie/bcdata.sgs.20716/dados/ultimos/10?formato=json` | Dados econômicos |
| FIPE | `https://parallelum.com.br/fipe/api/v1/carros/marcas` | Tabela FIPE de veículos |

## Como usar nos projetos

```typescript
// Exemplo com TanStack Query
const { data } = useQuery({
  queryKey: ['weather', city],
  queryFn: () => fetch(`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max`).then(r => r.json()),
  staleTime: 5 * 60 * 1000,
});
```

Content was rephrased for compliance with licensing restrictions.
Sources: [Mixed Analytics Free APIs List](https://mixedanalytics.com/blog/list-), [GitHub public-api-lists](https://github.com/public-api-lists/public-api-lists)
