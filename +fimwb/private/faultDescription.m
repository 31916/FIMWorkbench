function text=faultDescription(kind)
switch kind
    case 'bias', text='Bias / Offset adds Value to the signal, in the signal''s units.';
    case 'gain', text='Gain multiplies the signal by Value. A factor of 1 preserves its value.';
    case 'negate', text='Negate reverses the signal''s sign.';
    case 'absolute', text='Absolute outputs the absolute value of the signal.';
    case 'invert', text='Invert outputs 1 for zero and 0 for a nonzero input.';
    case 'zero', text='Stuck-at 0 sets the signal to zero.';
    case 'stuck_at', text='Constant replacement holds the signal at Value.';
    case 'package_drop', text='Package Drop replaces the signal with Value.';
    case 'hold_last', text='Stuck-at holds the last correct sample before Start. Value is the initial value when Start is zero.';
    case 'delay', text='Time Delay uses Value in seconds. For a discrete signal, use a multiple of its sample period.';
    case 'noise', text='Noise adds band-limited white noise. Value is noise power. Period is in seconds, and Seed controls reproducibility.';
    case 'bit_flip', text='Bit Flip reverses a Boolean signal.';
    case 'ror', text='ROR replaces the relational operator with the selected comparison.';
    case 'lor', text='LOR replaces the logical operator. NXOR means exclusive NOR.';
    case 'asr', text='ASR changes the sum signs. Choose one + or - for each operand.';
    case 's2p', text='S2P replaces a sum with the product of its inputs.';
    case 'p2s', text='P2S replaces a product with the sum of its inputs.';
end
text=[text ' Start is inclusive. Stop is exclusive. Leave Stop blank to run until simulation ends.'];
end
