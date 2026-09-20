# The API as it runs on the server. Build context is backend/.
#
#   docker build -t family-api backend
#
# Two stages so the image carries the runtime and the published output, not
# the SDK and the source.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# The project file alone first: restore is then cached until a dependency
# actually changes, rather than on every edit to a .cs file.
COPY src/Family.Api/Family.Api.csproj src/Family.Api/
RUN dotnet restore src/Family.Api/Family.Api.csproj

COPY src/ src/
RUN dotnet publish src/Family.Api/Family.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .

# The runtime image ships a non-root `app` user; the server has no reason to
# run this as root.
USER app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Family.Api.dll"]
