
interface Int3Output {

  /**
   * Output the given integer.
   *
   * @return SUCCESS if the value will be output, FAIL otherwise.
   */
  
  command result_t output(uint8_t a,uint8_t b,uint8_t c,uint8_t d,uint8_t e);

  /**
   * Signal that the ouput operation has completed; success states
   * whether the operation was successful or not.
   *
   * @return SUCCESS always.
   *
   */
  event result_t outputComplete(result_t success);
}
