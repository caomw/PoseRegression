--[[
--script_poseregression_eachjoint.lua
--Namhoon Lee, The Robotics Institute, Carnegie Mellon University
--]]


local matio = require 'matio'
require 'optim'
require 'cudnn'
require 'cunn';
paths.dofile('util.lua')
paths.dofile('datafromlist.lua')
paths.dofile('create_network.lua')
paths.dofile('compute_distance.lua')


-- 0. settings
cutorch.setDevice(opt.GPU)
paths.dofile('load_settings.lua')

nPoolSize  = 13344
nTrainData = 10000
nTestData  = 2000

LOADSAVED = true


-- 1. load and normalize data
--
if not LOADSAVED then
	mydataloader = dataLoader{filename = '../data/lists/pos.txt'}

	--idx_pool = torch.randperm(nPoolSize)
	idx_pool  = torch.range(1,nPoolSize)
	idx_train = idx_pool:narrow(1,1,nTrainData)
	idx_test  = idx_pool:narrow(1,nTrainData+1,nTestData)

	trainset = mydataloader:get_crop_label(idx_train)
	testset  = mydataloader:get_crop_label(idx_test)
else
	trainset = matio.load('../mat/dataset/traindata.mat')
	testset  = matio.load('../mat/dataset/testdata.mat')
end
print (trainset); print (testset)
assert(testset.label:size(1) == nTestData); assert(testset.label:size(2) == nJoints*2)

-- indexing trainset
setmetatable(trainset,
{__index = function(t,i)
	return {t.data[i], t.label[i]}
end}
);
function trainset:size()
	return self.data:size(1)
end

-- normalization
mean = {}
stdv = {}
for i=1,3 do
	mean[i] = trainset.data[{ {}, {i}, {}, {} }]:mean()
	trainset.data[{ {}, {i}, {}, {} }]:add(-mean[i])

	stdv[i] = trainset.data[{ {}, {i}, {}, {} }]:std()
	trainset.data[{ {}, {i}, {}, {} }]:div(stdv[i])

	testset.data[{ {}, {i}, {}, {} }]:add(-mean[i])
	testset.data[{ {}, {i}, {}, {} }]:div(stdv[i])
end

print('Saving everything to: ' .. opt.save)
os.execute('mkdir -p ' .. opt.save)


-- 2. network
--
if opt.retrain ~= 'none' then
	assert(paths.filep(opt.retrain), 'File not found: ' .. opt.retrain)
	print('Loading model from file: ' .. opt.retrain)
	model = loadDataParallel(opt.retrain, opt.nGPU)
else
	model = create_network(modelNumber)
	cudnn.convert(model, cudnn)
end


-- 3. loss function
-- 
criterion = nn.ParallelCriterion():add(nn.MSECriterion(), 1/22):add(nn.MSECriterion(), 1/22):add(nn.MSECriterion(), 1/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 1/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 1/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 1/22):add(nn.MSECriterion(), 2/22):add(nn.MSECriterion(), 2/22)
criterion = criterion:cuda()


-- *change data to cuda 
trainset.data = trainset.data:cuda()
trainset.label = trainset.label:cuda()
testset.data = testset.data:cuda()
testset.label = testset.label:cuda()


-- *Optional
print(opt)
print(model)


-- 4. (NEW) TRAINING  
TRAINING = true
if TRAINING then
	paths.dofile('train_eachjoint.lua')
	epoch = opt.epochNumber
	for i=1, opt.nEpochs do
		train()
		epoch = epoch + 1
	end
	model:evaluate()
else 
	-- load existing model
	model = torch.load(modelSaved)
end


-- 5. test the network
--
evaluate()