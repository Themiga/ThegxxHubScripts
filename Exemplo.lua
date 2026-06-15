-- =========================================================
-- Módulos Principais e Addons (Configuração Pro)
-- =========================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- Criação da Janela Minimalista
local Window = Library:CreateWindow({
    Title = "NovoAprendiz",
    Footer = "By Themiga",
    Center = true,
    AutoShow = true,
    Resizable = false,
    ShowCustomCursor = false -- Desativado para um visual mais limpo
})

-- Abas Otimizadas com Ícones Profissionais (Lucide Icons)
local Tabs = {
    Main = Window:AddTab("Compra", "shopping-cart"),
    Venda = Window:AddTab("Venda", "dollar-sign"),
    Fazenda = Window:AddTab("Fazenda", "sprout"),
    ESP = Window:AddTab("ESP Loja", "eye"),
    Config = Window:AddTab("Configurações", "settings")
}

-- Variáveis Globais de Controle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local NetworkingModule = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
local StockItems = ReplicatedStorage:WaitForChild("StockValues"):WaitForChild("SeedShop"):WaitForChild("Items")

_G.ScriptRunning = true
local Blacklist = { ["ItemTemplate"] = true, ["Sheckles_Shelf"] = true, ["Robux_Shelf"] = true }
local MapaRaridades = {}
local CacheEstoqueLoja = {}
local ListaRaridadesUnicas = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Super", "Unknown"} 

-- =========================================================
-- Funções de Suporte (Core Engine)
-- =========================================================
local function ObterListaDeSementes()
    local sementes = {}
    for _, item in ipairs(StockItems:GetChildren()) do
        if not Blacklist[item.Name] then
            table.insert(sementes, item.Name)
        end
    end
    table.sort(sementes)
    return sementes
end

local TodosItens = ObterListaDeSementes()

local function ObterPlotJogador()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    for _, plot in ipairs(gardens:GetChildren()) do
        if string.match(plot.Name, "Plot") then
            local playerFrame = plot:FindFirstChild("Signs") and plot.Signs:FindFirstChild("Garden") and plot.Signs.Garden:FindFirstChild("CorePart") and plot.Signs.Garden.CorePart:FindFirstChild("SurfaceGui") and plot.Signs.Garden.CorePart.SurfaceGui:FindFirstChild("Player")
            local textLabel = playerFrame and playerFrame:FindFirstChild("TextLabel")
            if textLabel and (string.find(textLabel.Text, LocalPlayer.Name) or string.find(textLabel.Text, LocalPlayer.DisplayName)) then
                return plot
            end
        end
    end
    return nil
end

local function ObterColunasDePlantacao(plot)
    local colunas = {}
    local visual = plot:FindFirstChild("Visual")
    if visual then
        for _, filho in ipairs(visual:GetChildren()) do
            if string.match(filho.Name, "^PlantAreaColumn%d+") and filho:IsA("BasePart") then
                table.insert(colunas, filho)
            end
        end
    end
    return colunas
end

local function ValidarSementeNoInventario(toolName)
    if string.find(toolName, "%[") or string.find(toolName, "kg") then
        return false
    end
    if StockItems:FindFirstChild(toolName) then
        return true
    end
    return false
end

local function AtualizarDadosDaLoja()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local SeedShop = PlayerGui and PlayerGui:FindFirstChild("SeedShop")
    local NormalShop = SeedShop and SeedShop:FindFirstChild("Frame") and SeedShop.Frame:FindFirstChild("NormalShop")
    if not NormalShop then return {} end

    local ItensNaLoja = {}
    table.clear(CacheEstoqueLoja)

    for _, itemFrame in ipairs(NormalShop:GetChildren()) do
        if itemFrame:IsA("Frame") and itemFrame:FindFirstChild("Main_Frame") then
            local nomeItem = itemFrame.Name
            if Blacklist[nomeItem] then continue end
            
            local mainFrame = itemFrame.Main_Frame
            local stockStr = mainFrame:FindFirstChild("Stock_Text") and mainFrame.Stock_Text.Text or ""
            local stockNum = tonumber(string.match(stockStr, "%d+")) or 0
            local costStr = mainFrame:FindFirstChild("Cost_Text") and mainFrame.Cost_Text.Text or "0"
            local costNum = string.match(costStr, "%d+") or "0"
            local rarityStr = mainFrame:FindFirstChild("Rarity") and mainFrame.Rarity:FindFirstChild("Rarity_Text") and mainFrame.Rarity.Rarity_Text.Text or "Unknown"
            
            MapaRaridades[nomeItem] = rarityStr
            CacheEstoqueLoja[nomeItem] = stockNum

            if not table.find(ListaRaridadesUnicas, rarityStr) then
                table.insert(ListaRaridadesUnicas, rarityStr)
                Library.Options.IgnorarRaridades:SetValues(ListaRaridadesUnicas)
            end

            if stockNum > 0 then
                table.insert(ItensNaLoja, { Nome = nomeItem, Estoque = stockNum, Preco = costNum, Raridade = rarityStr })
            end
        end
    end
    return ItensNaLoja
end

-- =========================================================
-- Configuração da Interface Gráfica (UI Elements)
-- =========================================================

-- ABA COMPRA
local BuyBox = Tabs.Main:AddLeftGroupbox("Autobuy")
BuyBox:AddDropdown("SelecionarItens", { Values = TodosItens, Default = 0, Multi = true, Searchable = true, Text = "Itens para Comprar" })
BuyBox:AddDropdown("ModoCompra", { Values = {"Infinita (Loop)", "Quantidade Exata"}, Default = 1, Multi = false, Text = "Modo de Compra" })
BuyBox:AddSlider("QuantidadeLimite", { Text = "Limite de Unidades", Default = 10, Min = 1, Max = 500, Rounding = 0 })
BuyBox:AddSlider("VelocidadeCompra", { Text = "Velocidade (Segundos)", Default = 1, Min = 0.1, Max = 5, Rounding = 1 })
BuyBox:AddToggle("AutoCompra", { Text = "Ativar Auto Compra", Default = false, Risky = true })

-- ABA VENDA
local SellBox = Tabs.Venda:AddLeftGroupbox("Autosell")
SellBox:AddDropdown("IgnorarItensVenda", { Values = TodosItens, Default = 0, Multi = true, Searchable = true, Text = "Lista Negra de Itens" })
SellBox:AddDropdown("IgnorarRaridades", { Values = ListaRaridadesUnicas, Default = 0, Multi = true, Text = "Lista Negra de Raridades" })
SellBox:AddSlider("VelocidadeVenda", { Text = "Velocidade (Segundos)", Default = 0.5, Min = 0.1, Max = 3, Rounding = 1 })
SellBox:AddToggle("AutoVenda", { Text = "Ativar Auto Venda", Default = false })

-- ABA FAZENDA
local CollectBox = Tabs.Fazenda:AddLeftGroupbox("Coleta")
CollectBox:AddToggle("AutoCollect", { Text = "Ativar Auto Coleta", Default = false })
CollectBox:AddSlider("VelocidadeCollect", { Text = "Velocidade (Segundos)", Default = 0.5, Min = 0.1, Max = 3, Rounding = 1 })

local PlantBox = Tabs.Fazenda:AddRightGroupbox("Plantio")
PlantBox:AddToggle("AutoPlant", { Text = "Ativar Auto Plantio", Default = false })
PlantBox:AddSlider("VelocidadePlant", { Text = "Velocidade (Segundos)", Default = 0.5, Min = 0.1, Max = 3, Rounding = 1 })

-- ABA ESP LOJA
local EspBox = Tabs.ESP:AddLeftGroupbox("Estoque da Loja")
local LabelTracker = EspBox:AddLabel("Aguardando varredura inicial...", true)

-- ABA CONFIGURAÇÕES (Completa com Save/Theme Manager)
local MenuBox = Tabs.Config:AddLeftGroupbox("Controles do Menu")
MenuBox:AddLabel("Atalho de Abertura"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu Keybind" })
MenuBox:AddButton({ Text = "Remover Cheat (Unload)", Func = function() _G.ScriptRunning = false; Library:Unload() end })

-- Inicialização dos Gerenciadores Nativos da Linoria
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
SaveManager:SetFolder("NovoAprendiz_Themiga")

SaveManager:BuildConfigSection(Tabs.Config) -- Cria os botões de Salvar/Carregar automaticamente
ThemeManager:ApplyToTab(Tabs.Config)       -- Adiciona a seleção de cores na aba de Configs
Library.ToggleKeybind = Library.Options.MenuKeybind

-- =========================================================
-- Mecânicas de Automação (Loops Assíncronos)
-- =========================================================

-- Loop Auto Plantio (Otimizado: Varredura total semDropdown + Click Virtual)
task.spawn(function()
    while true do
        if not _G.ScriptRunning then break end
        
        if Library.Toggles.AutoPlant.Value then
            local plot = ObterPlotJogador()
            local colunas = plot and ObterColunasDePlantacao(plot)
            
            if colunas and #colunas > 0 then
                local sementeAlvo = nil
                
                for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and ValidarSementeNoInventario(tool.Name) then
                        sementeAlvo = tool
                        break
                    end
                end
                
                if not sementeAlvo and LocalPlayer.Character then
                    local heldTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if heldTool and ValidarSementeNoInventario(heldTool.Name) then
                        sementeAlvo = heldTool
                    end
                end
                
                if sementeAlvo and LocalPlayer.Character then
                    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local camera = workspace.CurrentCamera
                    
                    if humanoid and hrp and camera then
                        if sementeAlvo.Parent ~= LocalPlayer.Character then
                            humanoid:EquipTool(sementeAlvo)
                            task.wait(0.05)
                        end
                        
                        -- Seleciona qualquer coluna ativa do lote livremente
                        local colunaSorteada = colunas[math.random(1, #colunas)]
                        local tamanho = colunaSorteada.Size
                        
                        local offsetX = math.random(-tamanho.X/2, tamanho.X/2)
                        local offsetZ = math.random(-tamanho.Z/2, tamanho.Z/2)
                        local pontoClick = (colunaSorteada.CFrame * Vector3.new(offsetX, tamanho.Y/2, offsetZ))
                        
                        hrp.CFrame = CFrame.lookAt(pontoClick + Vector3.new(0, 4, 0), pontoClick)
                        task.wait(0.03)
                        
                        local cameraAntiga = camera.CFrame
                        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, pontoClick)
                        task.wait(0.03)
                        
                        local posTela, naTela = camera:WorldToViewportPoint(pontoClick)
                        
                        if naTela then
                            if mousemoveabs then mousemoveabs(posTela.X, posTela.Y) end
                            task.wait(0.02)
                            
                            VirtualInputManager:SendMouseButtonEvent(posTela.X, posTela.Y, 0, true, game, 1)
                            task.wait(0.03)
                            VirtualInputManager:SendMouseButtonEvent(posTela.X, posTela.Y, 0, false, game, 1)
                            
                            if mouse1click then mouse1click() end
                        end
                        
                        task.wait(0.02)
                        camera.CFrame = cameraAntiga
                    end
                end
            end
            task.wait(Library.Options.VelocidadePlant.Value)
        else
            task.wait(0.5)
        end
    end
end)

-- Loop ESP e Atualização de Cache
task.spawn(function()
    while task.wait(1) do
        if not _G.ScriptRunning then break end
        
        local itensLoja = AtualizarDadosDaLoja()
        local textoEsp = ""
        
        for _, item in ipairs(itensLoja) do
            textoEsp = textoEsp .. string.format("[%s] <b>%s</b> | %s ¢ | <font color='rgb(0,255,0)'>%d</font>\n", 
                item.Raridade, item.Nome, item.Preco, item.Estoque)
        end
        if textoEsp == "" then textoEsp = "Nenhum item disponível em estoque." end
        LabelTracker:SetText(textoEsp)
    end
end)

-- Loop Auto Compra
task.spawn(function()
    local quantidadeComprada = 0
    Library.Toggles.AutoCompra:OnChanged(function() quantidadeComprada = 0 end)

    while true do
        if not _G.ScriptRunning then break end
        if Library.Toggles.AutoCompra.Value then
            local modo = Library.Options.ModoCompra.Value
            local limite = Library.Options.QuantidadeLimite.Value
            
            if modo == "Quantidade Exata" and quantidadeComprada >= limite then
                Library.Toggles.AutoCompra:SetValue(false)
                continue
            end
            
            local itensSelecionados = Library.Options.SelecionarItens.Value
            for nomeDoItem, estaMarcado in pairs(itensSelecionados) do
                if estaMarcado then
                    local estoqueAtual = CacheEstoqueLoja[nomeDoItem] or 0
                    if estoqueAtual <= 0 then continue end
                    
                    local tamanhoByte = string.char(#nomeDoItem)
                    local stringFormatada = "i\000" .. tamanhoByte .. nomeDoItem
                    pcall(function() RemoteEvent:FireServer(unpack({ buffer.fromstring(stringFormatada) })) end)
                    
                    quantidadeComprada = quantidadeComprada + 1 
                end
            end
            task.wait(Library.Options.VelocidadeCompra.Value)
        else
            task.wait(0.1)
        end
    end
end)

-- Loop Auto Venda
task.spawn(function()
    local function TentarVender(tool)
        if not tool:IsA("Tool") then return end
        local fruitName = tool:GetAttribute("FruitName")
        local fruitId = tool:GetAttribute("Id")
        
        if fruitName and fruitId then
            if Library.Options.IgnorarItensVenda.Value[fruitName] then return end
            local rarity = MapaRaridades[fruitName] or "Unknown"
            if Library.Options.IgnorarRaridades.Value[rarity] then return end
            
            pcall(function() NetworkingModule.NPCS.SellFruit:Fire(fruitId) end)
            task.wait(0.05)
        end
    end

    while true do
        if not _G.ScriptRunning then break end
        if Library.Toggles.AutoVenda.Value then
            for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if not Library.Toggles.AutoVenda.Value then break end
                TentarVender(item)
            end
            if LocalPlayer.Character then
                for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
                    if not Library.Toggles.AutoVenda.Value then break end
                    TentarVender(item)
                end
            end
            task.wait(Library.Options.VelocidadeVenda.Value)
        else
            task.wait(0.5)
        end
    end
end)

-- Loop Auto Coleta
task.spawn(function()
    while true do
        if not _G.ScriptRunning then break end
        if Library.Toggles.AutoCollect.Value then
            local plot = ObterPlotJogador()
            if plot and plot:FindFirstChild("Plants") then
                for _, obj in ipairs(plot.Plants:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Name == "HarvestPrompt" then
                        obj.MaxActivationDistance = math.huge
                        obj.RequiresLineOfSight = false
                        if fireproximityprompt then fireproximityprompt(obj) end
                    end
                end
            end
            task.wait(Library.Options.VelocidadeCollect.Value)
        else
            task.wait(0.5)
        end
    end
end)

-- Ativa automaticamente a última configuração salva (se configurado como Autoload)
SaveManager:LoadAutoloadConfig()
