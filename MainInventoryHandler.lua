local InventoryHandler = {}
local RequestData = game.ReplicatedStorage.Events:WaitForChild("RequestData")
local ErrorMessage = require(game.ReplicatedStorage.WorldModules.Effects.ErrorMessage)
local RemoteHandler = game.ReplicatedStorage.Events:WaitForChild("RemoteHandler")
local SynchronizeInventory = game.ReplicatedStorage.Events:WaitForChild("SynchronizeInventory")
local InspectRemote = game.ReplicatedStorage.Events:WaitForChild("Inspect")
local InteractionHandler = require(script.Parent:WaitForChild("InteractionHandler"))

local Plr = game.Players.LocalPlayer
local PlayerGUI = Plr.PlayerGui
local Mouse = Plr:GetMouse()

local InventoryUI = PlayerGUI:WaitForChild("InventoryFolder").Inventory
local PersonalFolder = InventoryUI.MainInventory.Frame.ScrollingFrame.Folder
local LootingFolder = InventoryUI.CurrentlyViewingInventory.Frame.ScrollingFrame.Folder
local InteractUI = PlayerGUI:WaitForChild("Interactables").Interact

local ItemData = require(game.ReplicatedStorage.WorldModules.Data.ItemData)
local CharacterHandler = require(script.Parent:WaitForChild("CharacterCreation"))
local Audio = game.ReplicatedStorage.Audio.SFX
local Transfer = game.ReplicatedStorage.Events:WaitForChild("Transfer")

function InventoryHandler.NewItem(ItemName,Amount,InventoryFolder,Data,Type)
	local self = {}

	local Default = require(script.Default)
	local FindType = require(script:FindFirstChild(Type))
	
	setmetatable(self, FindType)

	local function Sort(Table)
		for FunctionName,ActualFunction in pairs(Table) do

			if type(ActualFunction) == "function" then
				print(self)
				local Requirement = ActualFunction(self,true)
				
--				self:[FunctionName]()
				
				if Requirement == true then
					local InteractSlot = game.ReplicatedStorage.Templates.Interact:Clone()
					InteractSlot.Text = FunctionName
					InteractSlot.Parent = InteractUI.Frame.Folder

					InteractSlot.MouseButton1Down:Connect(function()
						--print(CharacterHandler.CurrentlyViewingInventory)
						
						ActualFunction(self)
						InteractionHandler.ClearPreviousUI()
					end)

				end


			end
		end
	end



	local function AddFunctionality(InvSlotUi)
		InvSlotUi.MouseButton2Down:Connect(function()
			InteractionHandler.ClearPreviousUI()
			InteractUI.Enabled = true
			InteractUI.Frame.Position = UDim2.new(0,Mouse.X+50,0,Mouse.Y+50)

			Sort(Default)
			Sort(FindType)

		end)

		InvSlotUi.MouseButton1Down:Connect(function()
			if CharacterHandler.CurrentlyViewingInventory ~= nil then
				if self.CurrentInventory == LootingFolder then
					InventoryHandler.Transfer(1,self,LootingFolder,PersonalFolder) --, Amount, Self, Origin, Destination
				elseif self.CurrentInventory == PersonalFolder then
					InventoryHandler.Transfer(1,self,PersonalFolder,LootingFolder) --, Amount, Self, Origin, Destination
				end

			end

		end)
	end


	local InvSlotUi = game.ReplicatedStorage.Templates.InvSlot:Clone()
	InvSlotUi.Parent = InventoryFolder
	InvSlotUi:WaitForChild("ImageLabel").Image = Data.Img
	InvSlotUi.ItemName.Text = ItemName
	InvSlotUi.Amount.Text = Amount

	self.CurrentInventory = InventoryFolder
	self.Name = ItemName
	self.Amount = Amount
	self.TotalWeight = Amount * Data.Weight

	self.UI = InvSlotUi
	self.AmountUI = InvSlotUi.Amount
	self.ItemNameUI = InvSlotUi.ItemName

	for ValueName,Value in pairs(Data) do
		self[ValueName] = Value
	end

	AddFunctionality(InvSlotUi)


	return self
end


function InventoryHandler.ModifyItem(ItemName : string ,Amount : number ,Folder : Folder)
	
	local InventoryName = Folder.Parent.Parent.Parent.Name -- Personal or looting

	
	local Found = false
	local RetrieveData = ItemData.Data[ItemName]
	local Type = RetrieveData.Type
	local Weight = RetrieveData.Weight
	
	local Check = InventoryHandler.CheckWeight(Amount,Weight,Folder)
	if Check == false then return end
	
	for i,Object in pairs(CharacterHandler[InventoryName]) do
		if Object.Name == ItemName then
			Found = true
			Object.Amount += Amount
			Object.AmountUI.Text = Object.Amount
			Object.TotalWeight = Object.Amount * Object.Weight
			
			if Object.Amount == 0 then
				Object.UI:Destroy()
				table.remove(CharacterHandler[InventoryName],i)
			end
		end
	end
	
	if Found == false then
		--local NewObject = require(script[Type]).new(ItemName,Amount,Folder,RetrieveData)
		--NewObject.Character = CharacterHandler
		local NewObject = InventoryHandler.NewItem(ItemName,Amount,Folder,RetrieveData,Type)
		table.insert(CharacterHandler[InventoryName],NewObject)

	end
	
	InventoryHandler.UpdateWeight(Folder)
	
	
	
end

function InventoryHandler.UpdateWeight(Folder)

	local InventoryName = Folder.Parent.Parent.Parent.Name
	local WeightUI = Folder.Parent.Parent.InventoryName.Weight
	local TotalWeight = 0

	for i,Object in pairs(CharacterHandler[InventoryName]) do
		TotalWeight += Object.TotalWeight 
	end

	WeightUI.Text = TotalWeight .. "/" .. CharacterHandler[InventoryName .. "MaxCapacity"]
end

function InventoryHandler.CheckWeight(Amount,Weight,Folder)



	local InventoryName = Folder.Parent.Parent.Parent.Name
	local GetMaxCapacity = CharacterHandler[InventoryName .. "MaxCapacity"]
	local TotalWeight = 0

	for i,Object in pairs(CharacterHandler[InventoryName]) do
		TotalWeight += Object.TotalWeight 
	end

	if TotalWeight + (Amount * Weight) > GetMaxCapacity then
		return false
	end

	return true

end

function InventoryHandler.GenerateSavedInventory(Data)

	
end

function InventoryHandler.ResetInventory()
	for i,Item in pairs(CharacterHandler.CurrentlyViewingInventory) do
		Item.UI:Destroy()
		table.remove(CharacterHandler.CurrentlyViewingInventory,i)
	end

end

function InventoryHandler.Transfer(TransferingAmount,self,OriginFolder,DestinationFolder)
	
	local CheckWeight
	CheckWeight = InventoryHandler.CheckWeight(TransferingAmount,self.Weight,DestinationFolder)
	
	
	if CheckWeight == false then ErrorMessage.Interact("Inventory Full",Plr) return end

	Audio.Transfer:Play()
	InventoryHandler.ModifyItem(self.Name,-TransferingAmount,OriginFolder)
	InventoryHandler.ModifyItem(self.Name,TransferingAmount,DestinationFolder)
	
	


	if DestinationFolder == PersonalFolder then
		self.CurrentInventory = PersonalFolder
		RemoteHandler:FireServer(game.ReplicatedStorage.WorldModules.Effects.ModifyItem,{

			--Inventory = CharacterHandler.Interacting.Inventory,
			ItemName = self.Name,
			Amount = -TransferingAmount,
		})
		
		Transfer:FireServer(self.Name,-TransferingAmount,CharacterHandler.Interacting)
		
	elseif DestinationFolder == LootingFolder then
		self.CurrentInventory = LootingFolder
		RemoteHandler:FireServer(game.ReplicatedStorage.WorldModules.Effects.ModifyItem,{

		--	Inventory = CharacterHandler.Interacting.Inventory,
			ItemName = self.Name,
			Amount = TransferingAmount,
		})	
		
		Transfer:FireServer(self.Name,TransferingAmount,CharacterHandler.Interacting)
		
	end
end


InspectRemote.OnClientEvent:Connect(function(Inventory)
	InventoryUI.Enabled = true
	InventoryUI.CurrentlyViewingInventory.Frame.Visible = true
	if CharacterHandler.CurrentlyViewingInventory then
		InventoryHandler.ResetInventory()
	end
	
	CharacterHandler.CurrentlyViewingInventory = {}
	CharacterHandler.CurrentlyViewingInventoryMaxCapacity = Inventory:GetAttribute("MaxCapacity") 
	
	for Index,Item in pairs(Inventory:GetChildren()) do
		InventoryHandler.ModifyItem(Item.Name,Item.Value,LootingFolder) -- Name, Amount, Folder
	end
end)


SynchronizeInventory.OnClientEvent:Connect(function(ItemName,Amount)
	
	
	InventoryHandler.ModifyItem(ItemName,Amount,LootingFolder)
end)


return InventoryHandler
