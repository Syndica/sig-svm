#include <stdbool.h>

typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef signed short int16_t;
typedef unsigned short uint16_t;
typedef signed int int32_t;
typedef unsigned int uint32_t;
typedef signed long int int64_t;
typedef unsigned long int uint64_t;
typedef int64_t ssize_t;
typedef uint64_t size_t;

#define SIZE_PUBKEY 32

typedef struct {
  uint8_t x[SIZE_PUBKEY];
} SolPubkey;

typedef struct {
  SolPubkey *key;      /** Public key of the account */
  uint64_t *lamports;  /** Number of lamports owned by this account */
  uint64_t data_len;   /** Length of data in bytes */
  uint8_t *data;       /** On-chain data within this account */
  SolPubkey *owner;    /** Program that owns this account */
  uint64_t rent_epoch; /** The epoch at which this account will next owe rent */
  bool is_signer;      /** Transaction was signed by this account's key? */
  bool is_writable;    /** Is the account writable? */
  bool executable;     /** This account's data contains a loaded program (and is now read-only) */
} SolAccountInfo;

typedef struct {
  SolAccountInfo* ka; /** Pointer to an array of SolAccountInfo, must already
                          point to an array of SolAccountInfos */
  uint64_t ka_num; /** Number of SolAccountInfo entries in `ka` */
  const uint8_t *data; /** pointer to the instruction data */
  uint64_t data_len; /** Length in bytes of the instruction data */
  const SolPubkey *program_id; /** program_id of the currently executing program */
} SolParameters;

static size_t sol_strlen(const char *s) {
  size_t len = 0;
  while (*s) {
    len++;
    s++;
  }
  return len;
}

void sol_log_compute_units_();
void abort();
void sol_log_(const char *msg, uint64_t);
void sol_log_64_(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);

#define SUCCESS 0
#define NULL 0

#define UINT8_MAX   (255)
#define UINT16_MAX  (65535)
#define UINT32_MAX  (4294967295U)
#define UINT64_MAX  (18446744073709551615UL)

#define MAX_PERMITTED_DATA_INCREASE (1024 * 10)

#define sol_log(message) sol_log_(message, sol_strlen(message))

static bool sol_deserialize(
  const uint8_t *input,
  SolParameters *params,
  uint64_t ka_num
) {
  if (NULL == input || NULL == params) {
    return false;
  }
  params->ka_num = *(uint64_t *) input;
  input += sizeof(uint64_t);

  for (int i = 0; i < params->ka_num; i++) {
    uint8_t dup_info = input[0];
    input += sizeof(uint8_t);

    if (i >= ka_num) {
      if (dup_info == UINT8_MAX) {
        input += sizeof(uint8_t);
        input += sizeof(uint8_t);
        input += sizeof(uint8_t);
        input += 4; // padding
        input += sizeof(SolPubkey);
        input += sizeof(SolPubkey);
        input += sizeof(uint64_t);
        uint64_t data_len = *(uint64_t *) input;
        input += sizeof(uint64_t);
        input += data_len;
        input += MAX_PERMITTED_DATA_INCREASE;
        input = (uint8_t*)(((uint64_t)input + 8 - 1) & ~(8 - 1)); // padding
        input += sizeof(uint64_t);
      } else {
        input += 7; // padding
      }
      continue;
    }
    if (dup_info == UINT8_MAX) {
      // is signer?
      params->ka[i].is_signer = *(uint8_t *) input != 0;
      input += sizeof(uint8_t);

      // is writable?
      params->ka[i].is_writable = *(uint8_t *) input != 0;
      input += sizeof(uint8_t);

      // executable?
      params->ka[i].executable = *(uint8_t *) input;
      input += sizeof(uint8_t);

      input += 4; // padding

      // key
      params->ka[i].key = (SolPubkey *) input;
      input += sizeof(SolPubkey);

      // owner
      params->ka[i].owner = (SolPubkey *) input;
      input += sizeof(SolPubkey);

      // lamports
      params->ka[i].lamports = (uint64_t *) input;
      input += sizeof(uint64_t);

      // account data
      params->ka[i].data_len = *(uint64_t *) input;
      input += sizeof(uint64_t);
      params->ka[i].data = (uint8_t *) input;
      input += params->ka[i].data_len;
      input += MAX_PERMITTED_DATA_INCREASE;
      input = (uint8_t*)(((uint64_t)input + 8 - 1) & ~(8 - 1)); // padding

      // rent epoch
      params->ka[i].rent_epoch = *(uint64_t *) input;
      input += sizeof(uint64_t);
    } else {
      params->ka[i].is_signer = params->ka[dup_info].is_signer;
      params->ka[i].is_writable = params->ka[dup_info].is_writable;
      params->ka[i].executable = params->ka[dup_info].executable;
      params->ka[i].key = params->ka[dup_info].key;
      params->ka[i].owner = params->ka[dup_info].owner;
      params->ka[i].lamports = params->ka[dup_info].lamports;
      params->ka[i].data_len = params->ka[dup_info].data_len;
      params->ka[i].data = params->ka[dup_info].data;
      params->ka[i].rent_epoch = params->ka[dup_info].rent_epoch;
      input += 7; // padding
    }
  }

  params->data_len = *(uint64_t *) input;
  input += sizeof(uint64_t);
  params->data = input;
  input += params->data_len;

  params->program_id = (SolPubkey *) input;
  input += sizeof(SolPubkey);

  return true;
}


#define sol_log_64 sol_log_64_

#define SOL_ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))
void sol_log_pubkey(const SolPubkey *);
static void sol_log_array(const uint8_t *array, int len) {
  for (int j = 0; j < len; j++) {
    sol_log_64(0, 0, 0, j, array[j]);
  }
}


static void sol_log_params(const SolParameters *params) {
  sol_log("- Program identifier:");
  sol_log_pubkey(params->program_id);

  sol_log("- Number of KeyedAccounts");
  sol_log_64(0, 0, 0, 0, params->ka_num);
  for (int i = 0; i < params->ka_num; i++) {
    sol_log("  - Is signer");
    sol_log_64(0, 0, 0, 0, params->ka[i].is_signer);
    sol_log("  - Is writable");
    sol_log_64(0, 0, 0, 0, params->ka[i].is_writable);
    sol_log("  - Key");
    sol_log_pubkey(params->ka[i].key);
    sol_log("  - Lamports");
    sol_log_64(0, 0, 0, 0, *params->ka[i].lamports);
    sol_log("  - data");
    sol_log_array(params->ka[i].data, params->ka[i].data_len);
    sol_log("  - Owner");
    sol_log_pubkey(params->ka[i].owner);
    sol_log("  - Executable");
    sol_log_64(0, 0, 0, 0, params->ka[i].executable);
    sol_log("  - Rent Epoch");
    sol_log_64(0, 0, 0, 0, params->ka[i].rent_epoch);
  }
  sol_log("- Instruction data\0");
  sol_log_array(params->data, params->data_len);
}

extern uint64_t entrypoint(const uint8_t *input) {
    SolAccountInfo ka[1];
    SolParameters params = (SolParameters) { .ka = ka };

    sol_log(__FILE__);

    if (!sol_deserialize(input, &params, SOL_ARRAY_SIZE(ka))) {
        abort();
    }

    // // Log the provided input parameters.  In the case of  the no-op
    // // program, no account keys or input data are expected but real
    // // programs will have specific requirements so they can do their work.
    sol_log_params(&params);

    sol_log_compute_units_();
    return SUCCESS;
}