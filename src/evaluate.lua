--[[ 
-- evaluate.lua
-- Namhoon Lee 
-- The Robotics Institute, Carnegie Mellon University
-- namhoonl@andrew.cmu.edu
--]]

local matio = require 'matio'


local function forwardpass(inputdataset)

	local label_gt   = torch.Tensor(inputdataset.label:size(1), 28):float()
	local label_pred = torch.Tensor(inputdataset.label:size(1), 28)

	for iSmp = 1,inputdataset.label:size(1) do
		local pred = model:forward(inputdataset.data[iSmp])
		local gt = inputdataset.label[iSmp]

		-- resize pred
		if type(pred) == 'table' then
			if table.getn(pred) == 2 then           -- structured & no filter
				pred = convert_multi_label(pred)
			elseif table.getn(pred) == 14 then
				if pred[1]:size(1) == 2 then        -- structured & no filter & each joint
					pred = convert_multi_nofilt_label(pred)
				elseif pred[1]:size(1) == 192 then  -- structured & filter
					gt = convert_filt_label(gt)
					pred = convert_multi_filt_label(pred)
				end
			end
		end

		-- case 2: a long filtered label
		if pred:size(1) == LLABEL and gt:size(1) == LLABEL then
			assert(LLABEL == 14*(64+128))
			pred = convert_filt_label(pred)
			gt = convert_filt_label(gt)
		end

		-- case 3: fcn label
		if pred:size(1) == nJoints and pred:size(2) == 32 and pred:size(3) == 16 then
			pred = convert_fcnlabel(pred)
			gt = convert_fcnlabel(gt)
		end

		-- At this stage, the size of lable should be 28
		assert(pred:size(1) == 2*nJoints)
		assert(gt:size(1) == 2*nJoints)

		label_gt[iSmp]   = gt:float()
		label_pred[iSmp] = pred 
	end


	return label_gt, label_pred
end


function evaluate(inputdataset, kind)

	-- 0. forward pass and convert labels to single vectors
	-- labels are all #Data x 28
	label_gt, label_pred = forwardpass(inputdataset)

	print(11)
	-- EVALUATE
	PCP = compute_PCP(label_gt, label_pred)
	EPJ, EPJ_avg = compute_epj(label_gt, label_pred)
	MSE_avg = compute_MSE(label_gt, label_pred)

	-- print out the results
	print(string.format('-- (%s)', kind))
	print(string.format('PCP     :   %.2f  (%%)', PCP))
	print(string.format('EPJ_avg :   %.4f', EPJ_avg))
	print(string.format('MSE_avg :   %.4f', MSE_avg))

	-- save prediction results for visualization
	pred_save = label_pred:double()
	matio.save(paths.concat(opt.save,string.format('pred_%s_%s.mat', kind, opt.t)), pred_save)
	--matio.save(string.format('pred_%s_%s.mat', kind, opt.t), pred_save)
end




