defmodule FullNodeTest do
  use ExUnit.Case
  doctest FullNode

  Application1.start(:abc, 10)

  # Unit test
  test "Check if inputs are valid" do
    assert UtilityFn.are_inputs_valid_and_difference(
             "B1D5781111D84F7B3FE45A0852E59758CD7A87E5",
             "10.0",
             [
               %{
                 difficulty: 1,
                 hash: "00C9793855C0EA58EA8A9F431D168CA4F9ADA248",
                 index: 1,
                 mrkl_root: "FirstBlock",
                 mrkl_tree: [],
                 n_tx: 0,
                 nonce: 28,
                 prev_hash: "00_000_000_000_000",
                 time: 1_542_078_479,
                 tx: [
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "356A192B7913B04C54574D18C28D46E6395428AB",
                         sender: "coinbase"
                       }
                     ],
                     txid: "5642D92C4A570A18110D989DC069B738B3CBAFF4"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0",
                         sender: "coinbase"
                       }
                     ],
                     txid: "24AA8CA073CDB6A0ACAA9D4D75EE902919510B3D"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "77DE68DAECD823BABBB58EDB1C8E14D7106E83BB",
                         sender: "coinbase"
                       }
                     ],
                     txid: "664C0C30514A14F6B07C8B8E7DDD2FF35C6DBD96"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "1B6453892473A467D07372D45EB05ABC2031647A",
                         sender: "coinbase"
                       }
                     ],
                     txid: "98C11B2E0D5FF9C477E12719D040ADDB4DB1BCDA"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "AC3478D69A3C81FA62E60F5C3696165A4E5E6AC4",
                         sender: "coinbase"
                       }
                     ],
                     txid: "357507E9E6E2E40704A3D487BB1C212702129380"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "C1DFD96EEA8CC2B62785275BCA38AC261256E278",
                         sender: "coinbase"
                       }
                     ],
                     txid: "FC1CD52F2156713366997E22B7E6A18D33369E9E"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "902BA3CDA1883801594B6E1B452790CC53948FDA",
                         sender: "coinbase"
                       }
                     ],
                     txid: "3ED25DE61F213AFA94985BFD38A2241886154519"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "FE5DBBCEA5CE7E2988B8C69BCFDFDE8904AABC1F",
                         sender: "coinbase"
                       }
                     ],
                     txid: "8A3D314BD1CB7AFF7F57033DFFC8853FECE4A2DD"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "0ADE7C2CF97F75D009975F4D720D1FA6C19F4897",
                         sender: "coinbase"
                       }
                     ],
                     txid: "483EF655E27AA1F5C70CBEE5E85D4AD07BAC0F06"
                   },
                   %{
                     in: [%{hash: "000000000", n: 0}],
                     out: [
                       %{
                         amount: 25.0,
                         n: 0,
                         receiver: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5",
                         sender: "coinbase"
                       }
                     ],
                     txid: "567E353A9DF286023A5214C5A2B7B5C70B971C64"
                   }
                 ]
               }
             ],
             [%{:hash => "567E353A9DF286023A5214C5A2B7B5C70B971C64", :n => 0}]
           ) == {true, 15.0}
  end

  # Functional test
  test "Create a transaction" do
    lst_of_nodes = Application1.start(:abc, 10)
    GenServer.cast(:wallet_0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1, {:make_transaction," 048BC7CF874FDFBA95B765BC803D4003BBF4E98081F854D5975DF2E528A336D0726AD5E859A4D9562602C0E29D620834D6510071C7DB21A99ABFEF0F10B637A4C9 10.0"  , [ %{ :hash => "8A12EB159B4EE7320FE4FF04F6C1088D5A8F078A", :n => 0 }]})
    curr_maps = Enum.map(lst_of_nodes, 
      fn x -> GenServer.call(x, {:get_state})
    end)
    #IO.inspect curr_maps

    for curr_map <- curr_maps,
      uncommitted_transaction <- curr_map.uncommitted_transactions,
        tx <- uncommitted_transaction do
          if tx.out.sender == "048BC7CF874FDFBA95B765BC803D4003BBF4E98081F854D5975DF2E528A336D0726AD5E859A4D9562602C0E29D620834D6510071C7DB21A99ABFEF0F10B637A4C9" do
            assert true
          end
    end

  end


  test "Verify entire chain" do
    assert GenServer.call(
          :"0443E747FC563ED3F7438DE87405B24A1DF47CF4A179D32A0B37DBBDFF25285A4437AB70A7FF54519CA8E780B7EA5710610BBED38E5F7EDA92870EE7F5F77783C2",
             {:full_verify,
              [
                %{
                  difficulty: 1,
                  hash: "00C9793855C0EA58EA8A9F431D168CA4F9ADA248",
                  index: 1,
                  mrkl_root: "FirstBlock",
                  mrkl_tree: [],
                  n_tx: 0,
                  nonce: 28,
                  prev_hash: "00_000_000_000_000",
                  time: 1_542_078_479,
                  tx: [
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "356A192B7913B04C54574D18C28D46E6395428AB",
                          sender: "coinbase"
                        }
                      ],
                      txid: "5642D92C4A570A18110D989DC069B738B3CBAFF4"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0",
                          sender: "coinbase"
                        }
                      ],
                      txid: "24AA8CA073CDB6A0ACAA9D4D75EE902919510B3D"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "77DE68DAECD823BABBB58EDB1C8E14D7106E83BB",
                          sender: "coinbase"
                        }
                      ],
                      txid: "664C0C30514A14F6B07C8B8E7DDD2FF35C6DBD96"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "1B6453892473A467D07372D45EB05ABC2031647A",
                          sender: "coinbase"
                        }
                      ],
                      txid: "98C11B2E0D5FF9C477E12719D040ADDB4DB1BCDA"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "AC3478D69A3C81FA62E60F5C3696165A4E5E6AC4",
                          sender: "coinbase"
                        }
                      ],
                      txid: "357507E9E6E2E40704A3D487BB1C212702129380"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "C1DFD96EEA8CC2B62785275BCA38AC261256E278",
                          sender: "coinbase"
                        }
                      ],
                      txid: "FC1CD52F2156713366997E22B7E6A18D33369E9E"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "902BA3CDA1883801594B6E1B452790CC53948FDA",
                          sender: "coinbase"
                        }
                      ],
                      txid: "3ED25DE61F213AFA94985BFD38A2241886154519"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "FE5DBBCEA5CE7E2988B8C69BCFDFDE8904AABC1F",
                          sender: "coinbase"
                        }
                      ],
                      txid: "8A3D314BD1CB7AFF7F57033DFFC8853FECE4A2DD"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "0ADE7C2CF97F75D009975F4D720D1FA6C19F4897",
                          sender: "coinbase"
                        }
                      ],
                      txid: "483EF655E27AA1F5C70CBEE5E85D4AD07BAC0F06"
                    },
                    %{
                      in: [%{hash: "000000000", n: 0}],
                      out: [
                        %{
                          amount: 25.0,
                          n: 0,
                          receiver: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5",
                          sender: "coinbase"
                        }
                      ],
                      txid: "567E353A9DF286023A5214C5A2B7B5C70B971C64"
                    }
                  ]
                }
              ]}
           ) == true
  end

  test "Verify block hash" do
    assert FullNode.verify_block_hash(
            %{
             difficulty: 1,
             hash: "00C9793855C0EA58EA8A9F431D168CA4F9ADA248",
             index: 1,
             mrkl_root: "FirstBlock",
             mrkl_tree: [],
             n_tx: 0,
             nonce: 28,
             prev_hash: "00_000_000_000_000",
             time: 1_542_078_479,
             tx: [
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "356A192B7913B04C54574D18C28D46E6395428AB",
                     sender: "coinbase"
                   }
                 ],
                 txid: "5642D92C4A570A18110D989DC069B738B3CBAFF4"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0",
                     sender: "coinbase"
                   }
                 ],
                 txid: "24AA8CA073CDB6A0ACAA9D4D75EE902919510B3D"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "77DE68DAECD823BABBB58EDB1C8E14D7106E83BB",
                     sender: "coinbase"
                   }
                 ],
                 txid: "664C0C30514A14F6B07C8B8E7DDD2FF35C6DBD96"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "1B6453892473A467D07372D45EB05ABC2031647A",
                     sender: "coinbase"
                   }
                 ],
                 txid: "98C11B2E0D5FF9C477E12719D040ADDB4DB1BCDA"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "AC3478D69A3C81FA62E60F5C3696165A4E5E6AC4",
                     sender: "coinbase"
                   }
                 ],
                 txid: "357507E9E6E2E40704A3D487BB1C212702129380"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "C1DFD96EEA8CC2B62785275BCA38AC261256E278",
                     sender: "coinbase"
                   }
                 ],
                 txid: "FC1CD52F2156713366997E22B7E6A18D33369E9E"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "902BA3CDA1883801594B6E1B452790CC53948FDA",
                     sender: "coinbase"
                   }
                 ],
                 txid: "3ED25DE61F213AFA94985BFD38A2241886154519"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "FE5DBBCEA5CE7E2988B8C69BCFDFDE8904AABC1F",
                     sender: "coinbase"
                   }
                 ],
                 txid: "8A3D314BD1CB7AFF7F57033DFFC8853FECE4A2DD"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "0ADE7C2CF97F75D009975F4D720D1FA6C19F4897",
                     sender: "coinbase"
                   }
                 ],
                 txid: "483EF655E27AA1F5C70CBEE5E85D4AD07BAC0F06"
               },
               %{
                 in: [%{hash: "000000000", n: 0}],
                 out: [
                   %{
                     amount: 25.0,
                     n: 0,
                     receiver: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5",
                     sender: "coinbase"
                   }
                 ],
                 txid: "567E353A9DF286023A5214C5A2B7B5C70B971C64"
               }
             ]
           }) == true
  end

  test "Check if all tansactions all valid in a block " do
    assert FullNode.check_if_all_transactions_valid(%{
      difficulty: 1,
      hash: "00C9793855C0EA58EA8A9F431D168CA4F9ADA248",
      index: 1,
      mrkl_root: "FirstBlock",
      mrkl_tree: [],
      n_tx: 0,
      nonce: 28,
      prev_hash: "00_000_000_000_000",
      time: 1_542_078_479,
      tx: [
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "356A192B7913B04C54574D18C28D46E6395428AB",
              sender: "coinbase"
            }
          ],
          txid: "5642D92C4A570A18110D989DC069B738B3CBAFF4"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0",
              sender: "coinbase"
            }
          ],
          txid: "24AA8CA073CDB6A0ACAA9D4D75EE902919510B3D"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "77DE68DAECD823BABBB58EDB1C8E14D7106E83BB",
              sender: "coinbase"
            }
          ],
          txid: "664C0C30514A14F6B07C8B8E7DDD2FF35C6DBD96"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "1B6453892473A467D07372D45EB05ABC2031647A",
              sender: "coinbase"
            }
          ],
          txid: "98C11B2E0D5FF9C477E12719D040ADDB4DB1BCDA"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "AC3478D69A3C81FA62E60F5C3696165A4E5E6AC4",
              sender: "coinbase"
            }
          ],
          txid: "357507E9E6E2E40704A3D487BB1C212702129380"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "C1DFD96EEA8CC2B62785275BCA38AC261256E278",
              sender: "coinbase"
            }
          ],
          txid: "FC1CD52F2156713366997E22B7E6A18D33369E9E"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "902BA3CDA1883801594B6E1B452790CC53948FDA",
              sender: "coinbase"
            }
          ],
          txid: "3ED25DE61F213AFA94985BFD38A2241886154519"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "FE5DBBCEA5CE7E2988B8C69BCFDFDE8904AABC1F",
              sender: "coinbase"
            }
          ],
          txid: "8A3D314BD1CB7AFF7F57033DFFC8853FECE4A2DD"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "0ADE7C2CF97F75D009975F4D720D1FA6C19F4897",
              sender: "coinbase"
            }
          ],
          txid: "483EF655E27AA1F5C70CBEE5E85D4AD07BAC0F06"
        },
        %{
          in: [%{hash: "000000000", n: 0}],
          out: [
            %{
              amount: 25.0,
              n: 0,
              receiver: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5",
              sender: "coinbase"
            }
          ],
          txid: "567E353A9DF286023A5214C5A2B7B5C70B971C64"
        }
      ]
    }) == true
  end

  test "Mining" do
    assert GenServer

    GenServer.cast(:DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0, {:mine}) 
    ==
      [
        %{
          amount: 25.0,
          n: 0,
          receiver: "DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0",
          sender: "coinbase"
        },
        %{
          amount: 15.0,
          n: 1,
          receiver: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5",
          sender: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5"
        },
        %{
          amount: 10.0,
          n: 0,
          receiver: "AC3478D69A3C81FA62E60F5C3696165A4E5E6AC4",
          sender: "B1D5781111D84F7B3FE45A0852E59758CD7A87E5"
        }
      ]
  end

 

end
