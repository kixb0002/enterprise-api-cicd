# Enterprise API CI/CD

Projet de reference pour une API ASP.NET Core avec tests unitaires, tests d'integration et conteneur Docker.

## Structure du projet

```text
enterprise-api-cicd/
|-- src/
|   `-- Enterprise.Api/
|       |-- Program.cs
|       |-- Enterprise.Api.csproj
|       |-- appsettings.json
|       |-- appsettings.Development.json
|       `-- Properties/
|           `-- launchSettings.json
|-- tests/
|   |-- Enterprise.Api.UnitTests/
|   |   |-- UnitTest1.cs
|   |   |-- GlobalUsings.cs
|   |   `-- Enterprise.Api.UnitTests.csproj
|   `-- Enterprise.Api.IntegrationTests/
|       |-- UnitTest1.cs
|       |-- WeatherForecastTests.cs
|       |-- GlobalUsings.cs
|       `-- Enterprise.Api.IntegrationTests.csproj
|-- Dockerfile
|-- .dockerignore
|-- EnterpriseApi.sln
|-- EnterpriseApi.slnx
`-- README.md
```

## Creation du projet

Commandes utilisees pour creer la solution, l'API et les projets de tests :

```powershell
mkdir enterprise-api-cicd
cd enterprise-api-cicd

dotnet new sln -n EnterpriseApi

mkdir src tests
dotnet new webapi -n Enterprise.Api -o src/Enterprise.Api
dotnet new xunit -n Enterprise.Api.UnitTests -o tests/Enterprise.Api.UnitTests
dotnet new xunit -n Enterprise.Api.IntegrationTests -o tests/Enterprise.Api.IntegrationTests

dotnet sln add src/Enterprise.Api/Enterprise.Api.csproj
dotnet sln add tests/Enterprise.Api.UnitTests/Enterprise.Api.UnitTests.csproj
dotnet sln add tests/Enterprise.Api.IntegrationTests/Enterprise.Api.IntegrationTests.csproj

dotnet add tests/Enterprise.Api.UnitTests reference src/Enterprise.Api
dotnet add tests/Enterprise.Api.IntegrationTests reference src/Enterprise.Api
```

## Package pour les tests d'integration

Le projet de tests d'integration utilise `Microsoft.AspNetCore.Mvc.Testing`.

Commande :

```powershell
dotnet add tests/Enterprise.Api.IntegrationTests package Microsoft.AspNetCore.Mvc.Testing
```

Ce package permet de demarrer l'API en memoire pendant les tests avec `WebApplicationFactory<Program>`.

## API

Le fichier principal de l'API est :

```text
src/Enterprise.Api/Program.cs
```

Endpoints disponibles :

```text
GET /health
GET /ready
GET /version
GET /api/products
GET /api/products/{id}
```

Exemples :

```powershell
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/version
curl http://localhost:8080/api/products
curl http://localhost:8080/api/products/1
```

## Tests unitaires

Fichier :

```text
tests/Enterprise.Api.UnitTests/UnitTest1.cs
```

Les tests verifient que :

- le prix d'un produit est positif ;
- l'identifiant d'un produit est positif.

Commande :

```powershell
dotnet test tests/Enterprise.Api.UnitTests/Enterprise.Api.UnitTests.csproj
```

## Tests d'integration

Fichier :

```text
tests/Enterprise.Api.IntegrationTests/UnitTest1.cs
```

Les tests verifient que ces routes retournent `200 OK` :

- `/health`
- `/ready`
- `/api/products`

Commande :

```powershell
dotnet test tests/Enterprise.Api.IntegrationTests/Enterprise.Api.IntegrationTests.csproj
```

Pour lancer tous les tests de la solution :

```powershell
dotnet test EnterpriseApi.sln
```

## Build local

Depuis la racine du projet :

```powershell
cd C:\Users\taoufik.mellah\cicd\enterprise-api-cicd
dotnet restore
dotnet build EnterpriseApi.sln
dotnet test EnterpriseApi.sln
```

Important : ces commandes necessitent un SDK .NET installe, pas seulement le runtime.

Verifier les SDK installes :

```powershell
dotnet --list-sdks
```

## Dockerfile

Le fichier `Dockerfile` construit l'application en deux etapes :

- `build` : utilise l'image SDK .NET 8 pour restaurer et publier l'application ;
- `runtime` : utilise l'image ASP.NET Core Runtime 8 pour executer l'application.

Commande de build Docker :

```powershell
docker build -t enterprise-api:local .
```

Explication :

- `docker build` construit une image Docker ;
- `-t enterprise-api:local` donne le nom `enterprise-api` et le tag `local` ;
- `.` indique que le contexte Docker est le dossier courant.

Commande de lancement :

```powershell
docker run -p 8080:8080 enterprise-api:local
```

Explication :

- `docker run` demarre un conteneur ;
- `-p 8080:8080` connecte le port `8080` du PC au port `8080` du conteneur ;
- `enterprise-api:local` est l'image a lancer.

L'API est ensuite accessible sur :

```text
http://localhost:8080
```

Routes utiles :

```text
http://localhost:8080/health
http://localhost:8080/ready
http://localhost:8080/version
http://localhost:8080/api/products
```

## .dockerignore

Le fichier `.dockerignore` evite d'envoyer des fichiers inutiles a Docker pendant le build.

Contenu :

```text
bin/
obj/
.git/
.github/
.vscode/
README.md
```

Explication :

- `bin/` ignore les fichiers compiles localement ;
- `obj/` ignore les fichiers temporaires de build .NET ;
- `.git/` ignore l'historique Git ;
- `.github/` ignore les workflows GitHub Actions ;
- `.vscode/` ignore la configuration locale de VS Code ;
- `README.md` ignore la documentation pendant le build Docker.

## Dossier depuis lequel lancer Docker

Les commandes Docker doivent etre lancees depuis la racine du projet, c'est-a-dire le dossier qui contient `Dockerfile` :

```powershell
cd C:\Users\taoufik.mellah\cicd\enterprise-api-cicd
```

Puis :

```powershell
docker build -t enterprise-api:local .
docker run -p 8080:8080 enterprise-api:local
```

## Script Azure

Le script suivant regroupe les commandes Azure executees manuellement pendant la creation de l'environnement :

```text
scripts/create-azure-resources.ps1
```

Il permet de recreer :

- Azure Container Registry ;
- App Service Plan Linux ;
- Web App container ;
- slot `green` ;
- Always On ;
- Key Vault et secret `ApiSecret` ;
- Log Analytics Workspace ;
- Application Insights ;
- Managed Identity App Service ;
- roles RBAC `Key Vault Secrets User`, `AcrPull`, `Contributor`, `AcrPush` ;
- App Registration GitHub Actions ;
- federation OIDC GitHub Actions.

Avant de lancer le script, modifier cette variable :

```powershell
$GITHUB_ORG = "ton-user-ou-organisation"
```

Puis lancer depuis la racine du projet :

```powershell
.\scripts\create-azure-resources.ps1
```
