FROM julia:1.11

# Define o diretório de trabalho correto
WORKDIR /backend

# Copia apenas os arquivos de ambiente primeiro
COPY backend/Project.toml backend/Manifest.toml ./

# Ativa o ambiente e instala os pacotes
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.add("ShiftedArrays");Pkg.precompile()'

# Copia o restante do backend
COPY backend/ ./

# Expõe a porta
EXPOSE 8000

# Executa o servidor
CMD ["julia", "--project=.", "server.jl"]
