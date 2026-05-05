# Utilise l'image SDK .NET 8 pour compiler, restaurer les packages et publier l'application.
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# Definit le repertoire de travail pour l'etape de build.
WORKDIR /src

# Copie le fichier solution dans le conteneur.
COPY EnterpriseApi.sln .

# Copie le fichier projet de l'API pour permettre le restore avec le cache Docker.
COPY src/Enterprise.Api/Enterprise.Api.csproj src/Enterprise.Api/

# Copie le fichier projet des tests unitaires pour restaurer leurs packages.
COPY tests/Enterprise.Api.UnitTests/Enterprise.Api.UnitTests.csproj tests/Enterprise.Api.UnitTests/

# Copie le fichier projet des tests d'integration pour restaurer leurs packages.
COPY tests/Enterprise.Api.IntegrationTests/Enterprise.Api.IntegrationTests.csproj tests/Enterprise.Api.IntegrationTests/

# Restaure les dependances NuGet de l'API.
RUN dotnet restore src/Enterprise.Api/Enterprise.Api.csproj

# Copie tout le code source et les autres fichiers du projet.
COPY . .

# Publie l'API en mode Release dans le dossier /app/publish sans refaire le restore.
RUN dotnet publish src/Enterprise.Api/Enterprise.Api.csproj \
    -c Release \
    -o /app/publish \
    --no-restore

# Utilise l'image runtime ASP.NET Core 8, plus legere que l'image SDK.
#FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled AS runtime

# Definit le repertoire de travail de l'application finale.
WORKDIR /app

# Copie les fichiers publies depuis l'etape build vers l'image runtime.
COPY --from=build /app/publish .

# Documente que le conteneur ecoute sur le port 8080.
EXPOSE 8080

# Configure ASP.NET Core pour ecouter sur toutes les interfaces reseau du conteneur.
ENV ASPNETCORE_URLS=http://+:8080

# Configure l'environnement ASP.NET Core en Production.
ENV ASPNETCORE_ENVIRONMENT=Production

# Lance l'application ASP.NET Core au demarrage du conteneur.
ENTRYPOINT ["dotnet", "Enterprise.Api.dll"]
