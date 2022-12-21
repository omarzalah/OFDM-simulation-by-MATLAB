%-------------------------------QPSK--------------------------------------
clc;
clear;
close all;
% Parameters:
Eb = 1;
Eb_Code=1;
A=1;
A_information=1/sqrt(3);
CP = 16;
L  = 1000;                   % Number of symbols (1000)
N  = L*(64+CP);              % Number of bits (40000)
SNR=-3:1:12;                  % Assumption SNR in (dB)
OFDM_SYM_nocode      = [];   % the OFDM symblos for no code
OFDM_SYM             = [];   % The OFDM symbols for code
QPSK_code_ifft_CYC   = [];   % the output from the cyclic extension
QPSK_nocode_ifft_CYC = [];
Receivied = [];              % the recevied data at the receiver
BER_QPSK_nocode = [];        %QPSK BER NO CODE
BER_QPSK_code   = [];        %QPSK BER coded
NO_OF_BITS_nocode=128;       %128 bits will be generated for no code
NO_OF_BITS_code=42;          %42 bits will be generated for coded to be 126
for x1 = 1:L
    information_bits1 = randi([0, 1], 1, NO_OF_BITS_nocode);
    information_bits2 = randi([0, 1], 1, NO_OF_BITS_code);
    NoCode_Bits=information_bits1;
    rep_bits = repelem(information_bits2, 3);
    rep_bits = [rep_bits, zeros(1,2)];
    
    % construct the OFDM symbols
    OFDM_SYM_nocode = [OFDM_SYM_nocode, NoCode_Bits];
    OFDM_SYM=[OFDM_SYM information_bits2];
    
 %-------------------------Interleaver block------------------------------
    % passing the data througth the interleaver block
     NOCODE_interleaver = matintrlv(NoCode_Bits, 8, 16);
     CODE_interleaver = matintrlv(rep_bits, 8, 16);
%---------------------------Mapper Block----------------------------------
    % mapping the data of no code into QPSK
    codeword_coded_QPSK = [];
    x2 = 1;
    for x3 = 1:2:128
        if (CODE_interleaver(x3) == 0 && CODE_interleaver(x3 + 1) == 0)
            codeword_coded_QPSK(x2) = -1 - 1i;
        elseif (CODE_interleaver(x3) == 0 && CODE_interleaver(x3 + 1) == 1)
            codeword_coded_QPSK(x2) = -1 + 1i;
        elseif (CODE_interleaver(x3) == 1 && CODE_interleaver(x3 + 1) == 0)
            codeword_coded_QPSK(x2) = 1 - 1i;
        elseif (CODE_interleaver(x3) == 1 && CODE_interleaver(x3 + 1) == 1)
            codeword_coded_QPSK(x2) = 1 + 1i;
        end
        x2 = x2 + 1;
    end
    % mapping the data of Code into QPSK
    codeword_no_code_QPSK = [];
    x2=1;
    for x3 = 1:2:128
        if (NOCODE_interleaver(x3) == 0 && NOCODE_interleaver(x3 + 1) == 0)
            codeword_no_code_QPSK(x2) = -1 - 1i;
        elseif (NOCODE_interleaver(x3) == 0 && NOCODE_interleaver(x3 + 1) == 1)
            codeword_no_code_QPSK(x2) = -1 + 1i;
        elseif (NOCODE_interleaver(x3) == 1 && NOCODE_interleaver(x3 + 1) == 0)
            codeword_no_code_QPSK(x2) = 1 - 1i;
        elseif (NOCODE_interleaver(x3) == 1 && NOCODE_interleaver(x3 + 1) == 1)
            codeword_no_code_QPSK(x2) = 1 + 1i;
        end
        x2 = x2 + 1;
    end
    % Passing the data througth the ifft block
    QPSK_code_ifft = ifft((codeword_coded_QPSK.*A_information), 64);
    QPSK_nocode_ifft =ifft(codeword_no_code_QPSK, 64);
    % Add the cyclic extension
    QPSK_code_ifft_CYC = [QPSK_code_ifft_CYC, QPSK_code_ifft(64 - CP + 1:64) QPSK_code_ifft];
    QPSK_nocode_ifft_CYC = [QPSK_nocode_ifft_CYC, QPSK_nocode_ifft(64 - CP + 1:64) QPSK_nocode_ifft];
end
% Ask for the channel type (Flat Fadding == 1) or (Frequncy Selective == 2)
CH_TP = menu('Choose the channle type', 'Flat Fadding', 'Frequency Selective');

% Passing the data througth the channel, then design the receiver
% Parameters
for x4 = SNR
    % Parameters
    remove_nocode_CYC = [];
    remove_coded_CYC = [];
    binary_nocode_received = [] ;
    binary_coded_received = [] ;
    received_nocode_bits = zeros(1,64);
    received_coded_bits = zeros(1,64);
    
    segma = 10 ^ (x4 / 10);
    N0 = Eb / segma;
    NO_coded=Eb_Code/segma;
    
    % Model the noise
    nc = normrnd(0, sqrt(N0 / 2), 1, N);
    ns = normrnd(0, sqrt(N0 / 2), 1, N);
    nc2 = normrnd(0, sqrt(NO_coded / 2), 1, N);
    ns2 = normrnd(0, sqrt(NO_coded / 2), 1, N);
    Noise_QPSK = (nc + 1j * ns)/sqrt(64);
    Noise_QPSK_code=(nc2+1j*ns2)/sqrt(64);
     if CH_TP == 1               % Flat Fadding channel
        %---------------------------------------------------------------%
        % CHANNEL_RAYLEIGH_FLAT_FADING_CHANNEL        
        % Eng.mohamed wa2el he said to remove Rayleigh channel from OFDM
        % hr = normrnd(0, sqrt(0.5), 1, L);
        %hi = normrnd(0, sqrt(0.5), 1, L);
        %channel_QPSK = hr + 1j * hi;
        
        % Passing the data througth the channel
        r_nocode = [];                % the output of the data after the channel and noise
        r_com_nocode = [];          % the ouput after the channel compensator
        r_code = [];                % the output of the data after the channel and noise
        r_com_code = [];          % the ouput after the channel compensator
        x5 = 1;
      for x6 = 1 : (CP + 64) : L * (CP + 64)
       r_nocode = [r_nocode, QPSK_nocode_ifft_CYC(x6:x6 + 63 + CP)];%* channel_QPSK(x5)];
       r_code   = [r_code  , QPSK_code_ifft_CYC(x6:x6 + 63 + CP)]; %* channel_QPSK(x5)];
       x5 = x5 + 1;
      end
              % Adding the noise
        noised_Data_nocode =r_nocode + Noise_QPSK;
        noised_Data_code = r_code + Noise_QPSK_code;
        % Design the receiver
        % First remove the channel effect
        x7 = 1;
        for x8 = 1 : (CP + 64) : L * (CP + 64)
            r_com_nocode = [r_com_nocode noised_Data_nocode(x8:x8 + CP +63) ];%/ channel_QPSK(x7)];
            r_com_code = [r_com_code noised_Data_code(x8:x8 + CP +63)];% / channel_QPSK(x7)];
            x7 = x7 + 1;
        end
    % Remove the cyclic effect, then de-map the signal, and pass throuth
    % the de-interleaver   
    % Remove the cyclic extension
    for x1 = 1 : (CP + 64) : (L * (CP + 64))
     remove_nocode_CYC = [remove_nocode_CYC r_com_nocode(x1 + CP:x1 + (CP + 63))];
     remove_coded_CYC  = [remove_coded_CYC r_com_code(x1 + CP:x1 + (CP + 63))];
    end
    % Passing througth the fft block to invert the effect the ifft
    for x1 = 1:64:64 * L
        %no code fft
        received_nocode_bits = remove_nocode_CYC(x1:x1 + 63);
        received_nocode_bits_fft = fft(received_nocode_bits, 64);
        bits_nocode_fft = received_nocode_bits_fft;
        %coded fft
        received_coded_bits = remove_coded_CYC(x1:x1 + 63);
        received_coded_bits_fft = fft(received_coded_bits, 64);
        bits_coded_fft = received_coded_bits_fft;
        % passing the data througth the de mapper
        bit_nocode_demapped = [];
        bit_coded_demapped = [];
        x2 = 1;
        for x3 = 1:64
            if (real(bits_nocode_fft(x3)) >= 0 && imag(bits_nocode_fft(x3)) >= 0)
                bit_nocode_demapped(x2)      = 1;
                bit_nocode_demapped(x2 + 1)  = 1;
            elseif (real(bits_nocode_fft(x3)) <= 0 && imag(bits_nocode_fft(x3)) >= 0)
                bit_nocode_demapped(x2)      = 0;
                bit_nocode_demapped(x2 + 1)  = 1;
            elseif (real(bits_nocode_fft(x3)) >= 0 && imag(bits_nocode_fft(x3)) <= 0)
                bit_nocode_demapped(x2)      = 1;
                bit_nocode_demapped(x2 + 1)  = 0;
            elseif (real(bits_nocode_fft(x3)) <= 0 && imag(bits_nocode_fft(x3)) <= 0)
                bit_nocode_demapped(x2)      = 0;
                bit_nocode_demapped(x2 + 1)  = 0;
            end
            x2 = x2 + 2;
        end
        x2 = 1;
        for x3 = 1:64
            if (real(bits_coded_fft(x3)) >= 0 && imag(bits_coded_fft(x3)) >= 0)
                bit_coded_demapped(x2)      = 1;
                bit_coded_demapped(x2 + 1)  = 1;
            elseif (real(bits_coded_fft(x3)) <= 0 && imag(bits_coded_fft(x3)) >= 0)
                bit_coded_demapped(x2)      = 0;
                bit_coded_demapped(x2 + 1)  = 1;
            elseif (real(bits_coded_fft(x3)) >= 0 && imag(bits_coded_fft(x3)) <= 0)
                bit_coded_demapped(x2)      = 1;
                bit_coded_demapped(x2 + 1)  = 0;
            elseif (real(bits_coded_fft(x3)) <= 0 && imag(bits_coded_fft(x3)) <= 0)
                bit_coded_demapped(x2)      = 0;
                bit_coded_demapped(x2 + 1)  = 0;
            end
            x2 = x2 + 2;
        end
        % Passing the data througth the de-interleaver
        bk_de_nocode_intrlv = matintrlv(bit_nocode_demapped, 16, 8);
        bk_de_nocode_intrlv_copy = bk_de_nocode_intrlv;
        
        bk_de_coded_intrlv = matintrlv(bit_coded_demapped, 16, 8);
        bk_de_coded_intrlv_copy = bk_de_coded_intrlv;
        %-------------------Decoder for coding----------------------------
        temp = [] ;
            x2 = 1;
            for i = 1:3:126
                NO_OF_ZEROS = nnz(~bk_de_coded_intrlv(i:i + 2)); % Get the number of zeros
                if NO_OF_ZEROS > 1
                    temp(x2) = 0;
                else
                    temp(x2) = 1;
                end
                x2 = x2 + 1;
            end
            bk_de_coded_intrlv_copy = temp;
        binary_coded_received = [binary_coded_received, bk_de_coded_intrlv_copy];    
        binary_nocode_received = [binary_nocode_received, bk_de_nocode_intrlv_copy];
    end
    % plotiing the data
    [~, Rat1] = biterr(OFDM_SYM_nocode, binary_nocode_received);
    BER_QPSK_nocode = [BER_QPSK_nocode, Rat1];
    [~, Rat2] = biterr(OFDM_SYM, binary_coded_received);
    BER_QPSK_code = [BER_QPSK_code, Rat2];
    %-------------------------------------------------------------------
    %--------------------------------- Frequncy Selective cghannel
        %----------------------------------------------------------------------%
    elseif CH_TP == 2                % Frequncy Selective cghannel
        %----------------------------------------------------------------------%
       No_code_Equilizer=[];
       Code_Equilizer=[];
       H=[0.4 0 0.26 0 0 0.4 0 0.6 0 0.5];
       H_FFT = fft(H, 64);
       %Passing the data througth the channel
        r_nocode = [];                % the output of the data after the channel and noise
        r_code = [];                % the output of the data after the channel and noise
        channel_nocode_sel = QPSK_nocode_ifft_CYC + Noise_QPSK;
        channel_code_sel = QPSK_code_ifft_CYC + Noise_QPSK_code;
        
        convolution_nocode = conv(channel_nocode_sel, H);
        convolution_code = conv(channel_code_sel, H);
        
        r_nocode = [r_nocode, convolution_nocode];
        r_code = [r_code, convolution_code];
        
        % Remove the cyclic extension
        r_nocode_new=r_nocode(1:(length(r_nocode)-length(H)+1));
        r_code_new=r_code(1:(length(r_code)-length(H)+1));
    
        for x1 = 1 : (CP + 64) : (L * (CP + 64))
          remove_nocode_CYC = [remove_nocode_CYC r_nocode_new(x1 + CP:x1 + (CP + 63))];
          remove_coded_CYC  = [remove_coded_CYC r_code_new(x1 + CP:x1 + (CP + 63))];
        end
        
        % Passing througth the fft block to invert the effect the ifft
    for x1 = 1:64:64 * L
        %no code fft
        received_nocode_bits = remove_nocode_CYC(x1:x1 + 63);
        received_nocode_bits_fft = fft(received_nocode_bits, 64);
        %coded fft
        received_coded_bits = remove_coded_CYC(x1:x1 + 63);
        received_coded_bits_fft = fft(received_coded_bits, 64);
         
        %Equilizer
        No_code_Equilizer=received_nocode_bits_fft./H_FFT;
        Code_Equilizer=received_coded_bits_fft./H_FFT;
        
        bits_nocode_fft = No_code_Equilizer;
        bits_coded_fft = Code_Equilizer;
        % passing the data througth the de mapper
        bit_nocode_demapped = [];
        bit_coded_demapped = [];
        x2 = 1;
        for x3 = 1:64
            if (real(bits_nocode_fft(x3)) >= 0 && imag(bits_nocode_fft(x3)) >= 0)
                bit_nocode_demapped(x2)      = 1;
                bit_nocode_demapped(x2 + 1)  = 1;
            elseif (real(bits_nocode_fft(x3)) <= 0 && imag(bits_nocode_fft(x3)) >= 0)
                bit_nocode_demapped(x2)      = 0;
                bit_nocode_demapped(x2 + 1)  = 1;
            elseif (real(bits_nocode_fft(x3)) >= 0 && imag(bits_nocode_fft(x3)) <= 0)
                bit_nocode_demapped(x2)      = 1;
                bit_nocode_demapped(x2 + 1)  = 0;
            elseif (real(bits_nocode_fft(x3)) <= 0 && imag(bits_nocode_fft(x3)) <= 0)
                bit_nocode_demapped(x2)      = 0;
                bit_nocode_demapped(x2 + 1)  = 0;
            end
            x2 = x2 + 2;
        end
        x2 = 1;
        for x3 = 1:64
            if (real(bits_coded_fft(x3)) >= 0 && imag(bits_coded_fft(x3)) >= 0)
                bit_coded_demapped(x2)      = 1;
                bit_coded_demapped(x2 + 1)  = 1;
            elseif (real(bits_coded_fft(x3)) <= 0 && imag(bits_coded_fft(x3)) >= 0)
                bit_coded_demapped(x2)      = 0;
                bit_coded_demapped(x2 + 1)  = 1;
            elseif (real(bits_coded_fft(x3)) >= 0 && imag(bits_coded_fft(x3)) <= 0)
                bit_coded_demapped(x2)      = 1;
                bit_coded_demapped(x2 + 1)  = 0;
            elseif (real(bits_coded_fft(x3)) <= 0 && imag(bits_coded_fft(x3)) <= 0)
                bit_coded_demapped(x2)      = 0;
                bit_coded_demapped(x2 + 1)  = 0;
            end
            x2 = x2 + 2;
        end
        % Passing the data througth the de-interleaver
        bk_de_nocode_intrlv = matintrlv(bit_nocode_demapped, 16, 8);
        bk_de_nocode_intrlv_copy = bk_de_nocode_intrlv;
        
        bk_de_coded_intrlv = matintrlv(bit_coded_demapped, 16, 8);
        bk_de_coded_intrlv_copy = bk_de_coded_intrlv;
        %-------------------Decoder for coding----------------------------
        temp = [] ;
            x2 = 1;
            for i = 1:3:126
                NO_OF_ZEROS = nnz(~bk_de_coded_intrlv(i:i + 2)); % Get the number of zeros
                if NO_OF_ZEROS > 1
                    temp(x2) = 0;
                else
                    temp(x2) = 1;
                end
                x2 = x2 + 1;
            end
            bk_de_coded_intrlv_copy = temp;
        binary_coded_received = [binary_coded_received, bk_de_coded_intrlv_copy];    
        binary_nocode_received = [binary_nocode_received, bk_de_nocode_intrlv_copy];
    end
    % plotiing the data
    [~, Rat1] = biterr(OFDM_SYM_nocode, binary_nocode_received);
    BER_QPSK_nocode = [BER_QPSK_nocode, Rat1];
    [~, Rat2] = biterr(OFDM_SYM, binary_coded_received);
    BER_QPSK_code = [BER_QPSK_code, Rat2];
        %----------------------------------------------------------------------%
     else                % Wrong Choise
        fprintf('Please choose the channel type\n');
        return;
    end
  
end

if CH_TP == 1
    figure;
    semilogy(SNR,BER_QPSK_nocode,'red');
    hold on
    semilogy(SNR,BER_QPSK_code,'green');
    hold on
    fprintf('With Flad Fadding Channel\n');
    title('BER vs. SNR for QPSK Flat Fadding channel');
    xlabel('SNR (dB)');
    ylabel('BER');
    legend('QPSK BER per information bit(no code Flat Fadding)','QPSK BER per information bit(Code Flat Fadding)');
elseif CH_TP == 2
    figure;
    semilogy(SNR,BER_QPSK_nocode,'red');
    hold on
    semilogy(SNR,BER_QPSK_code,'green');
    hold on
    fprintf('With Frequncy Selective Channel\n');
    title('BER vs. SNR for QPSK Frequency Selective channel');
    xlabel('SNR (dB)');
    ylabel('BER');
    legend('QPSK BER per information bit (no code Flat Fadding)','QPSK BER  per information bit (Code Flat Fadding)');
end

